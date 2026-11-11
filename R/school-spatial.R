# Descriptive aquatic animal group geometry, scoped to one camera/session.
# No inferred biological identity, leadership, preference, or welfare.

.aqt_group_observed <- function(tracks) {
  aqt_tracks_validate(tracks)
  if (!nrow(tracks)) return(as.data.frame(tracks))
  d <- as.data.frame(tracks)
  axes <- c("x","y",if (identical(attr(tracks,"aqt_dimension"),3L)) "z")
  d[d$observed & stats::complete.cases(d[,axes,drop=FALSE]),,drop=FALSE]
}

.aqt_group_pairs <- function(d,axes) {
  n <- nrow(d)
  if (n<2L) return(matrix(integer(),ncol=2L))
  utils::combn(seq_len(n),2L)
}

#' All simultaneous observed inter-fish distances within a camera/session
#'
#' Each unordered pair is reported once for each exact shared timestamp.
#' Original camera-local fish IDs are used; identities are never merged
#' across cameras or interpreted as permanent biological identifiers.
#' Missing or non-observed fish are excluded explicitly. Units are inherited
#' from the tracks and are physical only after valid spatial calibration.
#'
#' @param tracks Validated 2D/3D aqt_tracks.
#' @param max_pairs Maximum output pairs, to avoid accidental data explosion.
#' @return Long table of camera-local fish pairs and Euclidean distances.
#' @export
aqt_group_pairwise_distances <- function(tracks,max_pairs=1000000L) {
  aqt_tracks_validate(tracks)
  if (!is.numeric(max_pairs) || length(max_pairs)!=1L ||
      !is.finite(max_pairs) || max_pairs<1L ||
      max_pairs!=floor(max_pairs))
    stop("max_pairs must be a positive integer",call.=FALSE)
  cols <- c("session_id","camera_id","time_s","track_id_1","track_id_2",
            "distance")
  empty <- data.frame(session_id=character(),camera_id=character(),
    time_s=numeric(),track_id_1=character(),track_id_2=character(),
    distance=numeric())
  d <- .aqt_group_observed(tracks)
  if (!nrow(d)) return(empty)
  axes <- c("x","y",if (identical(attr(tracks,"aqt_dimension"),3L)) "z")
  keys <- interaction(d$session_id,d$camera_id,d$time_s,drop=TRUE)
  groups <- split(seq_len(nrow(d)),keys)
  expected <- sum(vapply(groups,function(idx) {
    z <- length(idx)
    as.double(z)*(z-1)/2
  },numeric(1L)))
  if (expected>max_pairs)
    stop("Pair cap exceeded; split by time/session",call.=FALSE)
  out <- lapply(groups,function(idx) {
    z <- d[idx,,drop=FALSE]
    n <- nrow(z)
    if (n<2L) return(NULL)
    pair <- t(utils::combn(seq_len(n),2L))
    coords <- as.matrix(z[,axes,drop=FALSE])
    dif <- coords[pair[,1L],,drop=FALSE]-coords[pair[,2L],,drop=FALSE]
    result <- data.frame(
      session_id=z$session_id[1L],camera_id=z$camera_id[1L],
      time_s=z$time_s[1L],
      track_id_1=z$track_id[pair[,1L]],
      track_id_2=z$track_id[pair[,2L]],
      distance=sqrt(rowSums(dif^2)))
    result
  })
  out <- Filter(Negate(is.null),out)
  if (!length(out)) return(empty)
  result <- do.call(rbind,unname(out))
  result <- result[order(result$session_id,result$camera_id,
                         result$time_s,result$track_id_1,
                         result$track_id_2),cols,drop=FALSE]
  rownames(result) <- NULL
  attr(result,"aqt_units") <- attr(tracks,"aqt_units")
  result
}

#' Simultaneous fish-school centroid, radius and spatial extent
#'
#' The radius of gyration is root mean squared Euclidean distance from
#' the school centroid. Extent is the maximum pairwise distance. A group
#' with only one visible fish has radius zero and undefined pairwise extent;
#' only groups with >= min_fish are returned.
#'
#' @param tracks Observed validated fish trajectories.
#' @param min_fish Required number of simultaneously visible fish (>=2).
#' @return Centroid XYZ, radius of gyration, mean pairwise distance and extent.
#' @export
aqt_group_spatial_summary <- function(tracks,min_fish=2L) {
  aqt_tracks_validate(tracks)
  if (!is.numeric(min_fish) || length(min_fish)!=1L ||
      !is.finite(min_fish) || min_fish<2L || min_fish!=floor(min_fish))
    stop("min_fish must be integer >=2",call.=FALSE)
  d <- .aqt_group_observed(tracks)
  if (!nrow(d)) return(data.frame())
  axes <- c("x","y",if (identical(attr(tracks,"aqt_dimension"),3L)) "z")
  keys <- interaction(d$session_id,d$camera_id,d$time_s,drop=TRUE)
  out <- lapply(split(seq_len(nrow(d)),keys),function(idx) {
    z <- d[idx,,drop=FALSE]
    if (nrow(z)<min_fish) return(NULL)
    xyz <- as.matrix(z[,axes,drop=FALSE])
    centre <- colMeans(xyz)
    squared <- rowSums(sweep(xyz,2L,centre,"-")^2)
    pair <- as.vector(stats::dist(xyz))
    data.frame(session_id=z$session_id[1L],
       camera_id=z$camera_id[1L],time_s=z$time_s[1L],
       n_visible=nrow(z),
       centroid_x=centre[1L],centroid_y=centre[2L],
       centroid_z=if (length(centre)==3L) centre[3L] else NA_real_,
       radius_gyration=sqrt(mean(squared)),
       mean_pair_distance=mean(pair),
       group_extent=max(pair))
  })
  out <- Filter(Negate(is.null),out)
  if (!length(out)) return(data.frame())
  ans <- do.call(rbind,unname(out))
  ans <- ans[order(ans$session_id,ans$camera_id,ans$time_s),,drop=FALSE]
  rownames(ans) <- NULL
  attr(ans,"aqt_units") <- attr(tracks,"aqt_units")
  ans
}

#' Thresholded fish-school spatial association edge list
#'
#' Every edge means two visible fish were within the declared Euclidean
#' distance at exactly the same timestamp. Association is not leadership,
#' causality, attraction, social preference or consistent individual identity.
#' @param tracks Canonical 2D/3D tracks.
#' @param radius Positive proximity threshold in coordinate units.
#' @param max_pairs Maximum candidate pairs before filtering.
#' @return Long edge list with pairwise distances and timestamp.
#' @export
aqt_group_spatial_edges <- function(tracks,radius,max_pairs=1000000L) {
  if (!is.numeric(radius) || length(radius)!=1L ||
      !is.finite(radius) || radius<=0)
    stop("radius must be positive and finite",call.=FALSE)
  pairs <- aqt_group_pairwise_distances(tracks,max_pairs)
  out <- pairs[pairs$distance<=radius,,drop=FALSE]
  attr(out,"aqt_units") <- attr(tracks,"aqt_units")
  out
}

#' Shannon occupancy entropy for a 3D voxelized fish tank
#'
#' Counts are conditioned on positions inside the supplied voxel grid.
#' Positions outside the grid are reported separately. These are observed
#' sample-based entropies and not continuous dwell-time uncertainty estimates.
#'
#' @param voxels Table returned by aqt_voxel_occupancy().
#' @return Per scoped group/fish entropy in bits and normalized entropy.
#' @export
aqt_voxel_entropy <- function(voxels) {
  required <- c("session_id","camera_id","track_id","ix","iy","iz",
                "n_samples","n_valid","n_outside")
  if (!is.data.frame(voxels) || !all(required %in% names(voxels)))
    stop("Expected aqt_voxel_occupancy table",call.=FALSE)
  if (!nrow(voxels)) return(data.frame())
  for (nm in c("n_samples","n_valid","n_outside")) {
    if (!is.numeric(voxels[[nm]]) ||
        any(!is.finite(voxels[[nm]])) ||
        any(voxels[[nm]]<0))
      stop("Voxel counts must be nonnegative and finite",call.=FALSE)
  }
  id <- as.character(voxels$track_id)
  id[is.na(id)] <- "<GROUP>"
  keys <- interaction(voxels$session_id,voxels$camera_id,id,drop=TRUE)
  rows <- lapply(split(seq_len(nrow(voxels)),keys),function(idx) {
    d <- voxels[idx,,drop=FALSE]
    if (length(unique(d$n_valid))!=1L ||
        length(unique(d$n_outside))!=1L)
      stop("Inconsistent voxel occupancy denominators",call.=FALSE)
    if (anyDuplicated(paste(d$ix,d$iy,d$iz,sep=":")))
      stop("Duplicate voxel cells",call.=FALSE)
    inside <- sum(d$n_samples)
    if (inside+d$n_outside[1L]!=d$n_valid[1L])
      stop("Voxel counts do not sum to valid observations",call.=FALSE)
    positive <- d$n_samples[d$n_samples>0]
    probs <- if (inside>0) positive/inside else numeric()
    entropy <- if (inside>0) -sum(probs*log2(probs)) else NA_real_
    k <- nrow(d)
    normalized <- if (inside==0) NA_real_ else
      if (k>1L) entropy/log2(k) else 0
    data.frame(session_id=d$session_id[1L],
      camera_id=d$camera_id[1L],track_id=d$track_id[1L],
      n_voxels=k,n_inside=inside,n_outside=d$n_outside[1L],
      n_valid=d$n_valid[1L],entropy_bits=entropy,
      entropy_normalized=normalized)
  })
  out <- do.call(rbind,unname(rows))
  rownames(out) <- NULL
  out
}
