# Wave 15A. Automatic geometric cross-view fish hypotheses and refractive 3D.
# No pair of fish is assumed biologically identical solely by its colour/ID.

#' Generate automatic two-camera refractive 3D fish match candidates
#'
#' Joins actual 2D fish observations under a supplied camera-clock tolerance
#' and traces through the declared refractive camera models. Every candidate
#' is an unreviewed geometric HYPOTHESIS, not confirmed biological identity.
#' Refuses inconsistent source camera geometry and overlarge candidate grids.
#'
#' @param view_a,view_b Validated single-camera 2D image-space aqt_tracks.
#' @param camera_a,camera_b Externally calibrated aqt_refraction_camera,
#'   including actual flatport camera models, in common physical units.
#' @param max_skew_s Maximum allowed *already-aligned* source timestamp skew.
#' @param max_ray_separation Maximum permitted closest-ray distance in world units.
#' @param max_candidates Upper bound on all generated time-compatible fish pairs.
#' @return Data frame with source identifiers, original timestamps, triangulated
#'   XYZ, ray-separation quality and validity; biological ID accuracy FALSE.
#' @export
aqt_refractive_view_candidates <- function(
    view_a,view_b,camera_a,camera_b,max_skew_s=.02,
    max_ray_separation=.5,max_candidates=100000L) {
  aqt_tracks_validate(view_a);aqt_tracks_validate(view_b)
  for (v in list(view_a,view_b)) {
    if (!identical(attr(v,"aqt_dimension"),2L) ||
        !identical(attr(v,"aqt_units"),"px") ||
        !identical(attr(v,"aqt_coordinate_system"),"image"))
      stop("Requires valid camera-local 2D image pixel tracks",call.=FALSE)
  }
  if (!inherits(camera_a,"aqt_refraction_camera") ||
      !inherits(camera_b,"aqt_refraction_camera") ||
      !identical(camera_a$units,camera_b$units))
    stop("Require two compatible explicitly calibrated refractive models",
         call.=FALSE)
  if (!is.numeric(max_skew_s) || length(max_skew_s)!=1L ||
      !is.finite(max_skew_s) || max_skew_s<0 ||
      !is.numeric(max_ray_separation) ||
      length(max_ray_separation)!=1L || is.na(max_ray_separation) ||
      max_ray_separation<0 ||
      !is.numeric(max_candidates) || length(max_candidates)!=1L ||
      !is.finite(max_candidates) || max_candidates<1L ||
      max_candidates!=floor(max_candidates))
    stop("Invalid positive candidate cap or nonnegative geometric/time limits",
         call.=FALSE)
  a <- as.data.frame(view_a); b <- as.data.frame(view_b)
  ca <- unique(a$camera_id);cb <- unique(b$camera_id)
  if (length(ca)!=1L || length(cb)!=1L || ca==cb)
    stop("Two distinct single-camera observation scopes are required",
         call.=FALSE)
  if (sqrt(sum((camera_a$center-camera_b$center)^2))<=1e-10)
    stop("Distinct optical camera centres are required",call.=FALSE)
  empty <- data.frame(candidate_id=character(),session_id=character(),
    camera_a=character(),camera_b=character(),id_a=character(),
    id_b=character(),time_a_s=numeric(),time_b_s=numeric(),
    time_skew_s=numeric(),x=numeric(),y=numeric(),z=numeric(),
    ray_separation=numeric(),valid=logical(),
    stringsAsFactors=FALSE)
  a <- a[a$observed & is.finite(a$x) & is.finite(a$y),,drop=FALSE]
  b <- b[b$observed & is.finite(b$x) & is.finite(b$y),,drop=FALSE]
  if (!nrow(a) || !nrow(b)) return(empty)
  pairs <- vector("list",0L); total <- 0L
  for (session in intersect(unique(a$session_id),unique(b$session_id))) {
    ia <- which(a$session_id==session)
    ib <- which(b$session_id==session)
    ib <- ib[order(b$time_s[ib],b$track_id[ib])]
    tb <- b$time_s[ib]
    for (i in ia) {
      lo <- .aqt_time_lower(tb,a$time_s[i]-max_skew_s)
      hi <- .aqt_time_upper(tb,a$time_s[i]+max_skew_s)
      if (hi<=lo) next
      js <- ib[seq.int(lo,hi-1L)]
      total <- total+length(js)
      if (total>max_candidates)
        stop("Fish cross-camera candidate cap exceeded",call.=FALSE)
      pairs[[length(pairs)+1L]] <- cbind(rep.int(i,length(js)),js)
    }
  }
  if (!length(pairs)) return(empty)
  links <- do.call(rbind,pairs)
  tri <- aqt_refractive_triangulate(camera_a,camera_b,
    as.matrix(a[links[,1L],c("x","y"),drop=FALSE]),
    as.matrix(b[links[,2L],c("x","y"),drop=FALSE]),
    max_separation=max_ray_separation)
  d <- data.frame(
    candidate_id=sprintf("refractive_%09d",seq_len(nrow(links))),
    session_id=a$session_id[links[,1L]],
    camera_a=ca,camera_b=cb,
    id_a=a$track_id[links[,1L]],
    id_b=b$track_id[links[,2L]],
    time_a_s=a$time_s[links[,1L]],
    time_b_s=b$time_s[links[,2L]],
    time_skew_s=abs(a$time_s[links[,1L]]-b$time_s[links[,2L]]),
    x=tri$x,y=tri$y,z=tri$z,
    ray_separation=tri$separation,
    valid=tri$valid,stringsAsFactors=FALSE)
  attr(d,"aqt_units") <- camera_a$units
  attr(d,"aqt_biological_identity_certified") <- FALSE
  attr(d,"aqt_clock_hardware_sync_certified") <- FALSE
  d
}

#' Automatically associate stable camera-local fish tracks across two views
#'
#' For each source A-track/B-track pair, selects one-to-one time-compatible
#' source observations, calculates temporal support and median physical
#' ray residual (or pinhole reprojection error), then greedily chooses
#' stable *provisional* track-pair identities across the recording.
#' A source ID is never paired with two other-view IDs in a session.
#' Competing pairs with equal support and similar geometry are abstained
#' from rather than assigned. Per-observation one-to-one constraints hold.
#' This is NOT independently reviewed biological fish reidentification.
#'
#' @param candidates Output of aqt_refractive_view_candidates() or
#'   aqt_view_candidates() containing exact camera-local source observations.
#' @param min_support Minimum distinct time pairs needed for a stable link.
#' @param max_error Maximum accepted ray-separation in physical units (or
#'   reprojection pixel error in pinhole candidates).
#' @param ambiguity_margin Minimum difference in median geometry error,
#'   in same units, to prefer two similarly supported competing links.
#' @return aqt_crossview_association list with checked correspondence rows,
#'   stable pairing table, source candidate counts and scientific caveats.
#' @export
aqt_crossview_auto_associate <- function(candidates,min_support=3L,
                                        max_error=.5,ambiguity_margin=.05) {
  need <- c("candidate_id","session_id","id_a","id_b",
            "time_a_s","time_b_s","time_skew_s","valid")
  if (!is.data.frame(candidates) || !all(need %in% names(candidates)) ||
      !any(c("ray_separation","reprojection_rmse_px") %in% names(candidates)))
    stop("Expected exact geometric cross-view source candidates",call.=FALSE)
  if (!is.numeric(min_support) || length(min_support)!=1L ||
      !is.finite(min_support) || min_support<1 ||
      min_support!=floor(min_support) ||
      !is.numeric(max_error) || length(max_error)!=1L ||
      is.na(max_error) || max_error<0 ||
      !is.numeric(ambiguity_margin) ||
      length(ambiguity_margin)!=1L ||
      !is.finite(ambiguity_margin) || ambiguity_margin<0)
    stop("Invalid minimum support, source geometry gate or ambiguity margin",
         call.=FALSE)
  error_col <- if ("ray_separation" %in% names(candidates))
    "ray_separation" else "reprojection_rmse_px"
  rows <- candidates
  if (anyDuplicated(rows$candidate_id) || anyNA(rows$candidate_id) ||
      anyNA(rows$valid) || !is.logical(rows$valid) ||
      any(!is.finite(rows$time_a_s)) ||
      any(!is.finite(rows$time_b_s)) ||
      any(!is.finite(rows$time_skew_s)) ||
      any(rows$time_skew_s<0) ||
      any(abs(abs(rows$time_a_s-rows$time_b_s)-
              rows$time_skew_s)>1e-7))
    stop("Invalid original candidate IDs, observations or source time skew",
         call.=FALSE)
  if (nrow(rows) && any(vapply(rows[c("session_id","id_a","id_b")],
     function(v)anyNA(v) || any(!nzchar(as.character(v))),logical(1L))))
    stop("Cross-camera source IDs cannot be blank",call.=FALSE)
  rows <- rows[rows$valid & is.finite(rows[[error_col]]) &
               rows[[error_col]]<=max_error,,drop=FALSE]
  blank <- data.frame(session_id=character(),id_a=character(),
    id_b=character(),fish_id=character(),
    n_supported_observations=integer(),median_geometry_error=numeric(),
    median_time_skew_s=numeric(),stringsAsFactors=FALSE)
  blank_links <- data.frame(session_id=character(),id_a=character(),
    id_b=character(),time_a_s=numeric(),time_b_s=numeric(),
    fish_id=character(),candidate_id=character(),
    matching_error=numeric(),stringsAsFactors=FALSE)
  if (!nrow(rows)) return(structure(list(
    correspondences=blank_links,links=blank,
    n_original_candidates=nrow(candidates),
    n_valid_candidates=0L,n_ambiguous_abstentions=0L,
    geometry_error_unit=if(error_col=="ray_separation")
      attr(candidates,"aqt_units") else "px",
    automatic_hypotheses_only=TRUE,
    independent_biological_identity_certified=FALSE),
    class="aqt_crossview_association"))
  pairkeys <- paste(rows$session_id,rows$id_a,rows$id_b,sep="\r")
  grouped <- split(seq_len(nrow(rows)),pairkeys)
  compact <- list(); measurements <- list()
  for (ids in grouped) {
    # Distinct time observations must remain one-to-one; choose smallest
    # geometric residual first and never reuse either camera observation.
    sorted <- ids[order(rows[[error_col]][ids],
                        rows$time_skew_s[ids],rows$candidate_id[ids])]
    used_a <- character();used_b <- character();keep <- integer()
    for (i in sorted) {
      ka <- paste(rows$session_id[i],rows$id_a[i],
                  sprintf("%.17g",rows$time_a_s[i]),sep="\r")
      kb <- paste(rows$session_id[i],rows$id_b[i],
                  sprintf("%.17g",rows$time_b_s[i]),sep="\r")
      if (ka %in% used_a || kb %in% used_b) next
      used_a <- c(used_a,ka);used_b <- c(used_b,kb)
      keep <- c(keep,i)
    }
    if (length(keep)<min_support) next
    j <- keep[1L]
    compact[[length(compact)+1L]] <- data.frame(
      session_id=rows$session_id[j],id_a=rows$id_a[j],id_b=rows$id_b[j],
      n_supported_observations=length(keep),
      median_geometry_error=stats::median(rows[[error_col]][keep]),
      median_time_skew_s=stats::median(rows$time_skew_s[keep]),
      stringsAsFactors=FALSE)
    measurements[[length(measurements)+1L]] <- keep
  }
  if (!length(compact)) return(structure(list(
    correspondences=blank_links,links=blank,
    n_original_candidates=nrow(candidates),
    n_valid_candidates=nrow(rows),n_ambiguous_abstentions=0L,
    geometry_error_unit=if(error_col=="ray_separation")
      attr(candidates,"aqt_units") else "px",
    automatic_hypotheses_only=TRUE,
    independent_biological_identity_certified=FALSE),
    class="aqt_crossview_association"))
  pair <- do.call(rbind,compact)
  pair <- pair[order(pair$session_id,
      -pair$n_supported_observations,pair$median_geometry_error,
      pair$median_time_skew_s,pair$id_a,pair$id_b),,drop=FALSE]
  # Restore the per-pair source row subsets after sorting.
  keys <- paste(pair$session_id,pair$id_a,pair$id_b,sep="\r")
  keys_compact <- vapply(compact,function(z)
    paste(z$session_id,z$id_a,z$id_b,sep="\r"),character(1L))
  measurement_for <- measurements[match(keys,keys_compact)]
  accepted <- list();accepted_obs <- list();usedA <- character();usedB <- character()
  abstained <- 0L
  for (k in seq_len(nrow(pair))) {
    p <- pair[k,,drop=FALSE]
    a_key <- paste(p$session_id,p$id_a,sep="\r")
    b_key <- paste(p$session_id,p$id_b,sep="\r")
    if (a_key %in% usedA || b_key %in% usedB) next
    rivals <- which(pair$session_id==p$session_id & (
        pair$id_a==p$id_a | pair$id_b==p$id_b))
    rivals <- setdiff(rivals,k)
    # Reject any pair whose rival has the same number of usable matched
    # timestamps and an indistinguishable median geometric fit.
    close <- rivals[pair$n_supported_observations[rivals]>=
                      p$n_supported_observations &
         abs(pair$median_geometry_error[rivals]-
               p$median_geometry_error)<ambiguity_margin]
    if (length(close)) {abstained <- abstained+1L;next}
    fish <- sprintf("AUTO_%s_%04d",gsub("[^[:alnum:]_-]","_",
      p$session_id),length(accepted)+1L)
    p$fish_id <- fish
    accepted[[length(accepted)+1L]] <- p
    idx <- measurement_for[[k]]
    data <- rows[idx,c("session_id","id_a","id_b",
                       "time_a_s","time_b_s","candidate_id"),drop=FALSE]
    data$fish_id <- fish
    data$matching_error <- rows[[error_col]][idx]
    accepted_obs[[length(accepted_obs)+1L]] <- data
    usedA <- c(usedA,a_key);usedB <- c(usedB,b_key)
  }
  links <- if(length(accepted))do.call(rbind,accepted) else blank
  obs <- if(length(accepted_obs))do.call(rbind,accepted_obs) else blank_links
  if (nrow(obs)) {
    ka <- paste(obs$session_id,obs$id_a,
                sprintf("%.17g",obs$time_a_s),sep="\r")
    kb <- paste(obs$session_id,obs$id_b,
                sprintf("%.17g",obs$time_b_s),sep="\r")
    if (anyDuplicated(ka) || anyDuplicated(kb))
      stop("Automatic source fish observations reused across 3D identities",
           call.=FALSE)
    obs <- obs[order(obs$session_id,obs$time_a_s,obs$fish_id),,drop=FALSE]
  }
  rownames(links)<-NULL;rownames(obs)<-NULL
  structure(list(correspondences=obs,links=links,
    n_original_candidates=nrow(candidates),n_valid_candidates=nrow(rows),
    n_ambiguous_abstentions=abstained,
    geometry_error_unit=if(error_col=="ray_separation")
      attr(candidates,"aqt_units") else "px",
    automatic_hypotheses_only=TRUE,
    independent_biological_identity_certified=FALSE,
    clock_synchronization_verified=FALSE),
    class="aqt_crossview_association")
}

#' Run automatic 2D cross-view association and refractive XYZ reconstruction
#'
#' Combines original refractive ray geometry, temporally supported provisional
#' globally one-to-one fish track associations and existing native R 3D
#' reconstruction. Does not fabricate matching IDs from camera-local labels,
#' actual camera clock synchronization, source fish species, or calibration.
#'
#' @param view_a,view_b Actual same-session 2D fish aqt_tracks with aligned
#'   but externally unverified camera time_s and undistorted image pixels.
#' @param camera_a,camera_b Properly parameterized refractive models.
#' @param max_skew_s Maximum actual time skew after supplied alignment.
#' @param max_ray_separation Valid geometrical ray distance in world units.
#' @param min_support,ambiguity_margin Automatic pairing reliability gates.
#' @return aqt_auto_refractive_pipeline list: source candidates, stable
#'   provisional source associations, and 3D trajectories or NULL if none.
#' @export
aqt_auto_refractive_pipeline <- function(
    view_a,view_b,camera_a,camera_b,
    max_skew_s=.02,max_ray_separation=.5,
    min_support=3L,ambiguity_margin=.05,max_candidates=100000L) {
  candidates <- aqt_refractive_view_candidates(
    view_a,view_b,camera_a,camera_b,max_skew_s=max_skew_s,
    max_ray_separation=max_ray_separation,max_candidates=max_candidates)
  matched <- aqt_crossview_auto_associate(
    candidates,min_support=min_support,
    max_error=max_ray_separation,ambiguity_margin=ambiguity_margin)
  if (!nrow(matched$correspondences)) {
    return(structure(list(candidates=candidates,
      association=matched,tracks_3d=NULL,
      diagnostics=NULL,status="no_unambiguous_crossview_track_pairs",
      source_fish_ids_are_provisional=TRUE,
      clock_hardware_synchronization_certified=FALSE,
      physical_xyz_accuracy_certified=FALSE,
      fish_biological_identity_certified=FALSE),
      class="aqt_auto_refractive_pipeline"))
  }
  d <- matched$correspondences
  cor <- d[,c("session_id","id_a","id_b","time_a_s","time_b_s",
              "fish_id"),drop=FALSE]
  cor$reviewer <- "UNREVIEWED_AUTOMATIC"
  cor$reason <- "stable_geometric_crossview_hypothesis"
  xyz <- aqt_refractive_reconstruct_tracks(
    view_a,view_b,cor,camera_a,camera_b,
    max_skew_s=max_skew_s,max_ray_separation=max_ray_separation)
  attr(xyz,"aqt_auto_fish_id_provisional") <- TRUE
  structure(list(candidates=candidates,association=matched,
    tracks_3d=xyz,diagnostics=aqt_refractive_track_quality(xyz),
    status="automatic_geometric_3d_hypotheses_reconstructed",
    source_fish_ids_are_provisional=TRUE,
    clock_hardware_synchronization_certified=FALSE,
    physical_xyz_accuracy_certified=FALSE,
    fish_biological_identity_certified=FALSE),
    class="aqt_auto_refractive_pipeline")
}
