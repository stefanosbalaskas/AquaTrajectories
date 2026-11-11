# Native, independently implemented trajectory comparison tools.
# These methods intentionally do not import any EyeTrajectories R contracts.

.aqt_single_path <- function(tracks,max_gap_s=Inf,min_n=2L) {
  aqt_tracks_validate(tracks)
  if (!is.numeric(max_gap_s) || length(max_gap_s)!=1L ||
      is.na(max_gap_s) || max_gap_s<=0)
    stop("max_gap_s must be positive",call.=FALSE)
  if (!nrow(tracks) ||
      length(unique(tracks$session_id))!=1L ||
      length(unique(tracks$camera_id))!=1L ||
      length(unique(tracks$track_id))!=1L)
    stop("Expected exactly one camera/session-scoped fish track",call.=FALSE)
  d <- as.data.frame(tracks)
  d <- d[order(d$time_s),,drop=FALSE]
  if (nrow(d)<min_n) stop("Insufficient observed trajectory samples",call.=FALSE)
  if (any(diff(d$time_s)<=0) || any(diff(d$time_s)>max_gap_s))
    stop("Duplicate timestamps or trajectory gaps exceed max_gap_s",call.=FALSE)
  coord <- c("x","y",if (identical(attr(tracks,"aqt_dimension"),3L)) "z")
  xyz <- as.matrix(d[,coord,drop=FALSE])
  if (any(!d$observed) || any(!is.finite(xyz)))
    stop("Trajectory contains missing or non-observed samples; segment it first",
         call.=FALSE)
  list(data=d,position=xyz,
       dimension=length(coord),
       units=attr(tracks,"aqt_units"),
       coordinate_system=attr(tracks,"aqt_coordinate_system"),
       axes=coord)
}

.aqt_compatible_paths <- function(a,b,max_gap_s=Inf) {
  x <- .aqt_single_path(a,max_gap_s)
  y <- .aqt_single_path(b,max_gap_s)
  if (x$dimension!=y$dimension || !identical(x$units,y$units) ||
      !identical(x$coordinate_system,y$coordinate_system))
    stop("Trajectories must share dimension, units and coordinate system",
         call.=FALSE)
  list(a=x,b=y)
}

#' Multivariate dynamic time warping for validated 2D/3D fish paths
#'
#' Computes Euclidean position distance at each aligned sample using
#' deterministic dynamic programming. The time-warping path is not physical
#' synchronized time, a fish identity match, or a causal mechanism.
#' Input trajectories must have complete observed coordinates, consistent
#' units and a single scoped fish ID each. Never interpolates missing points.
#'
#' @param track_a,track_b A single validated 2D or 3D aqt_tracks path each.
#' @param window Optional nonnegative Sakoe-Chiba band in sample indices;
#'   Inf (default) permits unrestricted warping.
#' @param max_gap_s Largest allowed sampling interval in either path.
#' @return List with total cost, cost per alignment pair, and alignment
#'   index/time path. Units equal the trajectory coordinate units.
#' @export
aqt_trajectory_dtw <- function(track_a,track_b,window=Inf,max_gap_s=Inf) {
  xy <- .aqt_compatible_paths(track_a,track_b,max_gap_s)
  a <- xy$a$position; b <- xy$b$position
  n <- nrow(a); m <- nrow(b)
  if (as.double(n)*m>2e6)
    stop("DTW cost matrix cap exceeded; segment recordings first",call.=FALSE)
  if (!is.numeric(window) || length(window)!=1L || is.na(window) ||
      window<0 || (is.finite(window) && window!=floor(window)))
    stop("window must be a nonnegative integer or Inf",call.=FALSE)
  if (window<abs(n-m))
    stop("Warping band is smaller than the input length difference",
         call.=FALSE)
  cumulative <- matrix(Inf,n+1L,m+1L)
  cumulative[1L,1L] <- 0
  previous <- matrix(0L,n,m)
  for (i in seq_len(n)) {
    from <- if (is.infinite(window)) 1L else max(1L, i-as.integer(window))
    to <- if (is.infinite(window)) m else min(m,i+as.integer(window))
    if (from>to) next
    for (j in seq.int(from,to)) {
      local <- sqrt(sum((a[i,]-b[j,])^2))
      # Deterministic tie order: diagonal, vertical, horizontal.
      options <- c(cumulative[i,j],cumulative[i,j+1L],
                   cumulative[i+1L,j])
      k <- which.min(options)
      cumulative[i+1L,j+1L] <- local+options[k]
      previous[i,j] <- k
    }
  }
  if (!is.finite(cumulative[n+1L,m+1L]))
    stop("No valid path under specified DTW window",call.=FALSE)
  i <- n; j <- m
  ia <- integer(n+m); ib <- integer(n+m)
  pos <- n+m
  while (i>0L || j>0L) {
    if (i<1L || j<1L || previous[i,j]==0L)
      stop("Internal DTW traceback failure",call.=FALSE)
    ia[pos] <- i; ib[pos] <- j
    step <- previous[i,j]
    if (step==1L) { i <- i-1L; j <- j-1L }
    else if (step==2L) { i <- i-1L }
    else { j <- j-1L }
    pos <- pos-1L
  }
  take <- seq.int(pos+1L,n+m)
  ia <- ia[take]; ib <- ib[take]
  total <- cumulative[n+1L,m+1L]
  list(distance=total,mean_step_distance=total/length(ia),
       n_alignment_pairs=length(ia),
       path=data.frame(index_a=ia,index_b=ib,
         time_a_s=xy$a$data$time_s[ia],time_b_s=xy$b$data$time_s[ib]),
       units=xy$a$units,dimension=xy$a$dimension,
       aligned_clocks=FALSE)
}

#' Pairwise DTW distance matrix across independently scoped fish tracks
#'
#' Each fish-camera-session scope contributes one path. Distances can mix
#' sessions only as shape comparisons, not as permanent fish identities.
#' All paths must be complete, in compatible position units and dimensions.
#' The distance is the total minimum alignment cost, not average cost.
#'
#' @param tracks Canonical aqt_tracks with at least two scoped fish paths.
#' @param window DTW window in sample indices.
#' @param max_gap_s Maximum valid observation interval in any path.
#' @return Symmetric numeric matrix of total alignment costs.
#' @export
aqt_trajectory_dtw_matrix <- function(tracks,window=Inf,max_gap_s=Inf) {
  aqt_tracks_validate(tracks)
  if (!nrow(tracks)) stop("No trajectories to compare",call.=FALSE)
  key <- interaction(tracks$session_id,tracks$camera_id,
                     tracks$track_id,drop=TRUE)
  groups <- split(seq_len(nrow(tracks)),key)
  n <- length(groups)
  if (n<2L || n>40L)
    stop("DTW matrix requires 2 to 40 independent scoped paths",call.=FALSE)
  xy <- lapply(groups,function(idx)
    aqt_tracks(as.data.frame(tracks[idx,,drop=FALSE]),
      units=attr(tracks,"aqt_units"),
      coordinate_system=attr(tracks,"aqt_coordinate_system")))
  labels <- vapply(xy,function(x)
    paste(x$session_id[1L],x$camera_id[1L],
          x$track_id[1L],sep="/"),character(1L))
  if (anyDuplicated(labels))
    stop("Ambiguous display labels for scoped trajectories",call.=FALSE)
  result <- matrix(0,n,n,dimnames=list(labels,labels))
  for (i in seq_len(n-1L)) for (j in seq.int(i+1L,n)) {
    v <- aqt_trajectory_dtw(xy[[i]],xy[[j]],
      window=window,max_gap_s=max_gap_s)$distance
    result[i,j] <- v
    result[j,i] <- v
  }
  attr(result,"aqt_units") <- attr(tracks,"aqt_units")
  result
}

.aqt_long_run_points <- function(x,min_length) {
  if (!length(x)) return(0L)
  rr <- rle(x)
  sum(rr$lengths[rr$values & rr$lengths>=min_length])
}

#' Recurrence quantification for a complete 2D or 3D fish path
#'
#' Euclidean position recurrence within a declared physical/pixel radius.
#' Excludes diagonal and short-temporal separations by a Theiler window.
#' Reports recurrence rate, diagonal-line determinism and vertical-line
#' laminarity. These are descriptive measures whose interpretation depends
#' on radius, sampling rate, tracking quality and tank geometry.
#'
#' @param track One validated scoped fish trajectory, with no missing samples.
#' @param radius Nonnegative recurrence distance in coordinate units.
#' @param theiler Exclude pair indices at |i-j| <= this integer (default 1).
#' @param min_diagonal Minimum diagonal recurrence run length >= 2.
#' @param min_vertical Minimum vertical recurrence run length >= 2.
#' @param max_gap_s Largest permitted inter-observation gap.
#' @param store_matrix Return logical recurrence matrix for visualization.
#' @return Descriptive RQA diagnostics, optionally the recurrence matrix.
#' @export
aqt_trajectory_recurrence <- function(track,radius,theiler=1L,
                                      min_diagonal=2L,min_vertical=2L,
                                      max_gap_s=Inf,store_matrix=FALSE) {
  x <- .aqt_single_path(track,max_gap_s,min_n=3L)
  n <- nrow(x$position)
  if (n>2000L) stop("Recurrence matrix cap exceeded (2000 observations)",
                    call.=FALSE)
  if (!is.numeric(radius) || length(radius)!=1L ||
      !is.finite(radius) || radius<0)
    stop("radius must be nonnegative and finite",call.=FALSE)
  for (v in list(theiler,min_diagonal,min_vertical))
    if (!is.numeric(v) || length(v)!=1L || !is.finite(v) ||
        v!=floor(v))
      stop("Recurrence window settings must be finite integers",call.=FALSE)
  if (theiler<0L || min_diagonal<2L || min_vertical<2L)
    stop("Invalid Theiler exclusion or recurrence run length",call.=FALSE)
  if (!is.logical(store_matrix) || length(store_matrix)!=1L ||
      is.na(store_matrix))
    stop("store_matrix must be TRUE or FALSE",call.=FALSE)
  indices <- seq_len(n)
  eligible <- abs(outer(indices,indices,"-"))>theiler
  d <- as.matrix(stats::dist(x$position))
  recurrent <- eligible & (d<=radius)
  n_eligible <- sum(eligible)
  n_recur <- sum(recurrent)
  diagonal_points <- 0L
  for (offset in seq.int(-n+1L,n-1L)) {
    ii <- indices
    jj <- ii+offset
    keep <- jj>=1L & jj<=n
    if (!any(keep)) next
    diagonal_points <- diagonal_points +
      .aqt_long_run_points(recurrent[cbind(ii[keep],jj[keep])],
                           min_diagonal)
  }
  vertical_points <- sum(vapply(seq_len(n),function(j)
    .aqt_long_run_points(recurrent[,j],min_vertical),numeric(1L)))
  ans <- list(n=n,n_pairs=n_eligible,n_recurrent=n_recur,
    recurrence_rate=if (n_eligible) n_recur/n_eligible else NA_real_,
    determinism=if (n_recur) diagonal_points/n_recur else NA_real_,
    laminarity=if (n_recur) vertical_points/n_recur else NA_real_,
    radius=radius,theiler=as.integer(theiler),
    min_diagonal=as.integer(min_diagonal),
    min_vertical=as.integer(min_vertical),units=x$units,
    interpretation="descriptive observed-position recurrence")
  if (store_matrix) ans$recurrence_matrix <- recurrent
  class(ans) <- "aqt_recurrence"
  ans
}

#' Plot a trajectory recurrence matrix
#' @param recurrence Result of aqt_trajectory_recurrence(store_matrix=TRUE).
#' @return Recurrence result invisibly; produces a base graphics image.
#' @export
aqt_plot_recurrence <- function(recurrence) {
  if (!inherits(recurrence,"aqt_recurrence") ||
      !is.matrix(recurrence$recurrence_matrix) ||
      !is.logical(recurrence$recurrence_matrix))
    stop("Require recurrence results with store_matrix=TRUE",
         call.=FALSE)
  m <- recurrence$recurrence_matrix
  graphics::image(seq_len(nrow(m)),seq_len(ncol(m)),
    1*m,xlab="Observation index",ylab="Observation index",
    main="Observed-position recurrence",
    col=c("#FFFFFF","#263A53"),asp=1)
  invisible(recurrence)
}
