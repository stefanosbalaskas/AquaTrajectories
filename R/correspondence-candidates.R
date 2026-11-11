# Candidate matching is geometry-aided REVIEW infrastructure, never
# automatic biological re-identification. All candidate scores are
# conditional on a declared, calibrated, non-refractive pinhole model.

.aqt_time_lower <- function(v,x) {
  lo <- 1L; hi <- length(v)+1L
  while (lo<hi) {
    m <- as.integer(floor((lo+hi)/2))
    if (v[m]<x) lo <- m+1L else hi <- m
  }
  lo
}
.aqt_time_upper <- function(v,x) {
  lo <- 1L; hi <- length(v)+1L
  while (lo<hi) {
    m <- as.integer(floor((lo+hi)/2))
    if (v[m]<=x) lo <- m+1L else hi <- m
  }
  lo
}

#' Generate geometric cross-view match candidates without assigning fish IDs
#'
#' Candidate pairs require shared session, temporally compatible observations
#' and valid two-view pinhole triangulation. Each source detection may appear
#' in MANY hypotheses. Reprojection error ranks geometrical consistency, not
#' biological identity. Refraction or an unknown optical path is rejected.
#'
#' @param view_a,view_b Two different camera-local 2D image aqt_tracks.
#' @param rig Explicitly non-refractive, calibrated aqt_rig.
#' @param max_skew_s Max allowed absolute difference between frame timestamps.
#' @param max_candidates Maximum possible pairs to materialize.
#' @return Candidate hypotheses including source scoped track/time IDs, XYZ,
#'   reprojection error and time skew. No candidate is automatically accepted.
#' @export
aqt_view_candidates <- function(view_a,view_b,rig,max_skew_s=.02,
                                max_candidates=100000L) {
  aqt_tracks_validate(view_a)
  aqt_tracks_validate(view_b)
  aqt_rig_validate(rig)
  if (!identical(rig$optical_path,"air_only"))
    stop("Cannot score geometry with unknown/refraction optical path",call.=FALSE)
  for (x in list(view_a,view_b)) {
    if (!identical(attr(x,"aqt_dimension"),2L) ||
        !identical(attr(x,"aqt_coordinate_system"),"image") ||
        !identical(attr(x,"aqt_units"),"px"))
      stop("Candidates require 2D pixel-space camera tracks",call.=FALSE)
  }
  if (length(max_skew_s)!=1L || !is.numeric(max_skew_s) ||
      !is.finite(max_skew_s) || max_skew_s<0)
    stop("max_skew_s must be nonnegative and finite",call.=FALSE)
  if (length(max_candidates)!=1L || !is.numeric(max_candidates) ||
      !is.finite(max_candidates) || max_candidates<1 ||
      max_candidates!=floor(max_candidates))
    stop("max_candidates must be a positive integer",call.=FALSE)
  a <- as.data.frame(view_a)
  b <- as.data.frame(view_b)
  ca <- unique(a$camera_id); cb <- unique(b$camera_id)
  if (length(ca)!=1L || length(cb)!=1L || ca==cb ||
      !all(c(ca,cb) %in% names(rig$projections)))
    stop("Expected distinct single cameras present in rig",call.=FALSE)
  if (aqt_rig_baseline(rig,ca,cb)<=1e-10)
    stop("Zero-length baseline cannot reconstruct stereo coordinates",call.=FALSE)
  empty <- data.frame(candidate_id=character(),session_id=character(),
    camera_a=character(),camera_b=character(),id_a=character(),
    id_b=character(),time_a_s=numeric(),time_b_s=numeric(),
    time_skew_s=numeric(),x=numeric(),y=numeric(),z=numeric(),
    reprojection_rmse_px=numeric(),valid=logical())
  a <- a[a$observed & !is.na(a$x) & !is.na(a$y),,drop=FALSE]
  b <- b[b$observed & !is.na(b$x) & !is.na(b$y),,drop=FALSE]
  if (!nrow(a) || !nrow(b)) return(empty)
  raw_links <- list()
  n_links <- 0L
  for (session in intersect(unique(a$session_id),unique(b$session_id))) {
    ia <- which(a$session_id==session)
    ib <- which(b$session_id==session)
    ib <- ib[order(b$time_s[ib],b$track_id[ib])]
    t_b <- b$time_s[ib]
    for (i in ia) {
      low <- .aqt_time_lower(t_b,a$time_s[i]-max_skew_s)
      high <- .aqt_time_upper(t_b,a$time_s[i]+max_skew_s)
      if (high<=low) next
      js <- ib[seq.int(low,high-1L)]
      if (n_links+length(js)>max_candidates)
        stop("Candidate cap exceeded; analyze time windows/chunks",call.=FALSE)
      raw_links[[length(raw_links)+1L]] <- cbind(
        rep.int(i,length(js)),js)
      n_links <- n_links+length(js)
    }
  }
  if (!length(raw_links)) return(empty)
  links <- do.call(rbind,raw_links)
  tri <- aqt_triangulate_pairs(
    as.matrix(a[links[,1L],c("x","y"),drop=FALSE]),
    as.matrix(b[links[,2L],c("x","y"),drop=FALSE]),
    rig$projections[[ca]],rig$projections[[cb]])
  result <- data.frame(candidate_id=sprintf("candidate_%08d",seq_len(nrow(links))),
    session_id=a$session_id[links[,1L]],
    camera_a=ca,camera_b=cb,
    id_a=a$track_id[links[,1L]],id_b=b$track_id[links[,2L]],
    time_a_s=a$time_s[links[,1L]],time_b_s=b$time_s[links[,2L]],
    time_skew_s=abs(a$time_s[links[,1L]]-b$time_s[links[,2L]]),
    x=tri$x,y=tri$y,z=tri$z,
    reprojection_rmse_px=tri$reprojection_rmse,
    valid=tri$valid)
  result
}

#' Rank cross-view geometry candidates and flag ambiguous matches
#'
#' A good reprojection fit is only a hypothesis. The function never returns
#' confirmed fish IDs. Use aqt_correspondences_from_review() for explicitly
#' human-verified selections. Rankings are scoped by source fish detection.
#'
#' @param candidates Candidate table from aqt_view_candidates().
#' @param max_reprojection_px Maximum tolerated reprojection error.
#' @return Candidate table with eligible, rank_a, n_eligible_a and
#'   second-best margin, all purely geometric.
#' @export
aqt_candidate_rank <- function(candidates,max_reprojection_px=2) {
  if (!is.data.frame(candidates) ||
      !all(c("candidate_id","session_id","id_a","time_a_s",
             "reprojection_rmse_px","valid") %in% names(candidates)))
    stop("Invalid candidate table",call.=FALSE)
  if (length(max_reprojection_px)!=1L ||
      !is.numeric(max_reprojection_px) || !is.finite(max_reprojection_px) ||
      max_reprojection_px<0)
    stop("max_reprojection_px must be finite and nonnegative",call.=FALSE)
  d <- candidates
  if (!nrow(d)) {
    d$eligible <- logical()
    d$rank_a <- integer()
    d$n_eligible_a <- integer()
    d$best_margin_px <- double()
    return(d)
  }
  if (anyDuplicated(d$candidate_id) ||
      anyNA(d$valid) || !is.logical(d$valid))
    stop("Invalid or repeated candidate identifiers",call.=FALSE)
  d$eligible <- d$valid & is.finite(d$reprojection_rmse_px) &
                d$reprojection_rmse_px<=max_reprojection_px
  d$rank_a <- NA_integer_
  d$n_eligible_a <- integer(nrow(d))
  d$best_margin_px <- NA_real_
  key <- .aqt_join_key(d$session_id,d$id_a,d$time_a_s)
  for (idx in split(seq_len(nrow(d)),key)) {
    eligible <- idx[d$eligible[idx]]
    d$n_eligible_a[idx] <- length(eligible)
    if (!length(eligible)) next
    ordered <- eligible[order(d$reprojection_rmse_px[eligible],
                               d$time_skew_s[eligible],d$candidate_id[eligible])]
    d$rank_a[ordered] <- seq_along(ordered)
    gap <- if (length(ordered)>=2L)
      d$reprojection_rmse_px[ordered[2L]] -
        d$reprojection_rmse_px[ordered[1L]]
      else Inf
    d$best_margin_px[idx] <- gap
  }
  d
}

#' Turn documented human-reviewed candidate selections into correspondences
#'
#' This method does not choose which matches are correct. It only checks the
#' review file and ensures a source observation is not assigned to several
#' fish. The reviewer remains responsible for biological identity claims.
#'
#' @param candidates Candidate table from aqt_view_candidates().
#' @param review Data frame with candidate_id, fish_id, reviewer, reason.
#' @return Explicit correspondences acceptable to aqt_reconstruct_3d().
#' @export
aqt_correspondences_from_review <- function(candidates,review) {
  needed <- c("candidate_id","session_id","id_a","id_b","time_a_s",
              "time_b_s","valid")
  .aqt_required(candidates,needed,"candidates")
  .aqt_required(review,c("candidate_id","fish_id","reviewer","reason"),"review")
  if (!nrow(review) || anyDuplicated(review$candidate_id) ||
      anyNA(review$candidate_id) ||
      any(!nzchar(trimws(as.character(review$candidate_id)))))
    stop("Review must select unique known candidates",call.=FALSE)
  for (nm in c("fish_id","reviewer","reason")) {
    if (anyNA(review[[nm]]) ||
        any(!nzchar(trimws(as.character(review[[nm]])))))
      stop("Reviews require fish_id, reviewer and reason",call.=FALSE)
  }
  idx <- match(as.character(review$candidate_id),candidates$candidate_id)
  if (anyNA(idx) || anyDuplicated(candidates$candidate_id))
    stop("Reviewed candidate missing or candidates not uniquely identified",call.=FALSE)
  selected <- candidates[idx,,drop=FALSE]
  if (anyNA(selected$valid) || any(!selected$valid))
    stop("Reviewed candidate has invalid stereo geometry",call.=FALSE)
  ka <- .aqt_join_key(selected$session_id,selected$id_a,selected$time_a_s)
  kb <- .aqt_join_key(selected$session_id,selected$id_b,selected$time_b_s)
  if (anyDuplicated(ka) || anyDuplicated(kb))
    stop("A source observation cannot be assigned to multiple fish",call.=FALSE)
  out <- selected[,c("session_id","id_a","id_b","time_a_s","time_b_s")]
  out$fish_id <- as.character(review$fish_id)
  out$reviewer <- as.character(review$reviewer)
  out$reason <- as.character(review$reason)
  out$candidate_id <- as.character(review$candidate_id)
  rownames(out) <- NULL
  out
}
