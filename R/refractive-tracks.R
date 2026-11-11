#' Reconstruct manually matched two-view fish tracks through refractive rays
#'
#' Accepts previously reviewed, exact camera-local fish correspondences.
#' The 2D observations must share calibrated clock time and pixel system,
#' but their biological source track IDs may be different. The supplied
#' refractive camera models can be ideal one-interface or two-interface
#' flat glass ports. Does not automatically discover fish correspondences.
#'
#' @param view_a,view_b Canonical single-camera 2D image/pixel tracks.
#' @param correspondences Data frame session_id, id_a, id_b,
#'   time_a_s,time_b_s,fish_id, with optional tank_id/treatment fields.
#' @param camera_a,camera_b Calibrated-parameter refractive camera models,
#'   with shared physical world coordinate units.
#' @param max_skew_s Maximum tolerated time difference after synchronization.
#' @param max_ray_separation Maximum accepted physical distance between
#'   closest underwater rays (cm or m, same as camera model).
#' @return 3D aqt_tracks with source IDs, clock skew, 3D ray separation,
#'   original reviewed assignments and explicit missing positions.
#' @export
aqt_refractive_reconstruct_tracks <- function(
    view_a,view_b,correspondences,camera_a,camera_b,
    max_skew_s=.02,max_ray_separation=Inf) {
  aqt_tracks_validate(view_a);aqt_tracks_validate(view_b)
  for (v in list(view_a,view_b)) {
    if (!identical(attr(v,"aqt_dimension"),2L) ||
        !identical(attr(v,"aqt_coordinate_system"),"image") ||
        !identical(attr(v,"aqt_units"),"px"))
      stop("Refractive reconstruction requires 2D pixel-space image tracks",
           call.=FALSE)
  }
  if (!inherits(camera_a,"aqt_refraction_camera") ||
      !inherits(camera_b,"aqt_refraction_camera") ||
      !identical(camera_a$units,camera_b$units))
    stop("Two comparable refractive camera models are required",
         call.=FALSE)
  if (!is.numeric(max_skew_s) || length(max_skew_s)!=1L ||
      !is.finite(max_skew_s) || max_skew_s<0)
    stop("max_skew_s must be finite nonnegative",call.=FALSE)
  if (!is.numeric(max_ray_separation) ||
      length(max_ray_separation)!=1L ||
      is.na(max_ray_separation) || max_ray_separation<0)
    stop("max_ray_separation must be nonnegative",call.=FALSE)
  a <- as.data.frame(view_a)
  b <- as.data.frame(view_b)
  c_a <- unique(a$camera_id)
  c_b <- unique(b$camera_id)
  if (length(c_a)!=1L || length(c_b)!=1L || c_a==c_b)
    stop("Each source view must have exactly one distinct camera ID",
         call.=FALSE)
  needed <- c("session_id","id_a","id_b","time_a_s","time_b_s","fish_id")
  if (!is.data.frame(correspondences) || !nrow(correspondences) ||
      !all(needed %in% names(correspondences)))
    stop("Require nonempty reviewed cross-camera correspondence table",
         call.=FALSE)
  paired <- as.data.frame(correspondences)
  for (nm in c("session_id","id_a","id_b","fish_id")) {
    if (anyNA(paired[[nm]]) || any(!nzchar(as.character(paired[[nm]]))))
      stop("Reviewed biological and source IDs must be explicit",
           call.=FALSE)
    paired[[nm]] <- as.character(paired[[nm]])
  }
  for (nm in c("time_a_s","time_b_s"))
    if (!is.numeric(paired[[nm]]) || any(!is.finite(paired[[nm]])))
      stop("Reviewed camera timestamps must be finite numeric",call.=FALSE)
  skew <- abs(paired$time_a_s-paired$time_b_s)
  if (any(skew>max_skew_s))
    stop("Source observations exceed permitted synchronization skew",
         call.=FALSE)
  k_a <- .aqt_join_key(paired$session_id,paired$id_a,paired$time_a_s)
  k_b <- .aqt_join_key(paired$session_id,paired$id_b,paired$time_b_s)
  ia <- match(k_a,.aqt_join_key(a$session_id,a$track_id,a$time_s))
  ib <- match(k_b,.aqt_join_key(b$session_id,b$track_id,b$time_s))
  if (anyNA(ia) || anyNA(ib))
    stop("Reviewed observations missing in source camera tracks",
         call.=FALSE)
  if (anyDuplicated(ia) || anyDuplicated(ib))
    stop("One source observation assigned to multiple fused fish",
         call.=FALSE)
  xy1 <- as.matrix(a[ia,c("x","y"),drop=FALSE])
  xy2 <- as.matrix(b[ib,c("x","y"),drop=FALSE])
  good <- a$observed[ia] & b$observed[ib] &
          stats::complete.cases(xy1) & stats::complete.cases(xy2)
  xy1[!good,] <- NA_real_
  xy2[!good,] <- NA_real_
  triangulated <- data.frame(x=rep(NA_real_,nrow(paired)),
    y=rep(NA_real_,nrow(paired)),z=rep(NA_real_,nrow(paired)),
    separation=rep(NA_real_,nrow(paired)),valid=rep(FALSE,nrow(paired)))
  if (any(good)) {
    tri <- aqt_refractive_triangulate(
      camera_a,camera_b,xy1[good,,drop=FALSE],
      xy2[good,,drop=FALSE],
      max_separation=max_ray_separation)
    triangulated[good,c("x","y","z","separation","valid")] <-
      tri[,c("x","y","z","separation","valid"),drop=FALSE]
  }
  if (!any(triangulated$valid))
    stop("No valid reviewed 3D refractive fish observations",call.=FALSE)
  d <- data.frame(session_id=paired$session_id,camera_id="REFRACTIVE3D",
    track_id=paired$fish_id,time_s=(paired$time_a_s+paired$time_b_s)/2,
    x=triangulated$x,y=triangulated$y,z=triangulated$z,
    observed=triangulated$valid,
    source_camera_a=c_a,source_camera_b=c_b,
    source_id_a=paired$id_a,source_id_b=paired$id_b,
    source_time_a_s=paired$time_a_s,source_time_b_s=paired$time_b_s,
    time_skew_s=skew,ray_separation=triangulated$separation)
  for (extra in c("tank_id","treatment","reviewer","reason"))
    if (extra %in% names(paired)) d[[extra]] <- paired[[extra]]
  out <- aqt_tracks(d,units=camera_a$units,coordinate_system="tank")
  attr(out,"aqt_refractive_models") <- c(
    model_a=camera_a$model,model_b=camera_b$model)
  attr(out,"aqt_calibration_certified") <- FALSE
  out
}

#' Audit physical ray residuals and clock skew in refractive 3D fish tracks
#'
#' All summaries are diagnostics conditional on the supplied camera model
#' and fish correspondences; neither low ray error nor successful R tests
#' establish absolute calibrated 3D world-position accuracy.
#'
#' @param tracks Output of aqt_refractive_reconstruct_tracks().
#' @return Per-session valid counts, missing fraction and ray/clock QC.
#' @export
aqt_refractive_track_quality <- function(tracks) {
  aqt_tracks_validate(tracks)
  req <- c("ray_separation","time_skew_s","session_id","observed")
  if (!all(req %in% names(tracks)) ||
      !identical(attr(tracks,"aqt_dimension"),3L))
    stop("Expected refractively reconstructed 3D fish tracks",
         call.=FALSE)
  groups <- split(seq_len(nrow(tracks)),tracks$session_id)
  out <- lapply(groups,function(idx) {
    d <- tracks[idx,,drop=FALSE]
    ok <- d$observed & is.finite(d$ray_separation)
    data.frame(session_id=d$session_id[1L],
      n_pairs=nrow(d),n_valid=sum(ok),fraction_valid=mean(ok),
      median_separation=if(any(ok))
        stats::median(d$ray_separation[ok]) else NA_real_,
      max_separation=if(any(ok))
        max(d$ray_separation[ok]) else NA_real_,
      max_skew_s=max(d$time_skew_s),
      calibration_certified=FALSE)
  })
  do.call(rbind,unname(out))
}
