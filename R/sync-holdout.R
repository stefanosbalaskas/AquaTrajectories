# Independent-event holdout audit for shared camera-clock synchronization.
# A small regression residual does not prove that physical sync pulses
# were real, detected correctly, or shared an actual hardware time base.

#' Fit camera clock offsets and drifts with independent sync-marker holdouts
#'
#' Fits affine mappings from camera time to one externally declared
#' reference camera using >=4 training pulses and >=2 disjoint physical
#' holdout pulses per session and camera. Unlike a simple two-point
#' offset/drift fit, it reports heldout residuals, offset and drift,
#' extrapolation risk and failure of a prespecified maximum clock error.
#' Markers must be physically corresponding events: matching text IDs
#' alone do not certify synchronization.
#'
#' @param markers Frame with session_id,camera_id,marker_id,time_s;
#'   all identifiers complete and every selected pulse in every camera.
#' @param reference_camera Name of reference camera.
#' @param train_markers,holdout_markers Disjoint unique character IDs
#'   of physical sync events, at least four and two respectively.
#' @param max_holdout_error_s Externally declared maximum absolute
#'   synchronization residual in seconds, strictly positive.
#' @return aqt_clock_holdout containing session/camera affine fits,
#'   individual heldout residuals and failed-tolerance flags.
#' @export
aqt_sync_holdout_fit <- function(
    markers,reference_camera,train_markers,holdout_markers,
    max_holdout_error_s=.005) {
  required <- c("session_id","camera_id","marker_id","time_s")
  if (!is.data.frame(markers) || !nrow(markers) ||
      !all(required %in% names(markers)))
    stop("Expected nonempty session/camera pulse marker table",call.=FALSE)
  m <- as.data.frame(markers)
  for (col in required[1:3]) {
    v <- as.character(m[[col]])
    if (anyNA(v) || any(!nzchar(trimws(v))))
      stop("Missing session, camera or pulse identifier",call.=FALSE)
    m[[col]] <- v
  }
  if (!is.numeric(m$time_s) || any(!is.finite(m$time_s)))
    stop("Sync pulse timestamps must be finite numeric seconds",call.=FALSE)
  if (anyDuplicated(paste(m$session_id,m$camera_id,
                          m$marker_id,sep="\r")))
    stop("Duplicate pulse ID within session and camera",call.=FALSE)
  if (!is.character(reference_camera) ||
      length(reference_camera)!=1L || is.na(reference_camera) ||
      !nzchar(trimws(reference_camera)))
    stop("Specify one reference camera",call.=FALSE)
  for (item in list(train_markers,holdout_markers))
    if (!is.character(item) || anyNA(item) ||
        any(!nzchar(trimws(item))) || anyDuplicated(item))
      stop("Training and holdout pulse IDs must be unique and complete",
           call.=FALSE)
  if (length(train_markers)<4L || length(holdout_markers)<2L ||
      any(train_markers %in% holdout_markers))
    stop("Need >=4 training and >=2 disjoint heldout pulse IDs",call.=FALSE)
  if (!is.numeric(max_holdout_error_s) ||
      length(max_holdout_error_s)!=1L ||
      !is.finite(max_holdout_error_s) || max_holdout_error_s<=0)
    stop("max_holdout_error_s must be a prespecified positive value",
         call.=FALSE)
  all_ids <- c(train_markers,holdout_markers)
  coeff <- list(); errors <- list(); cidx <- 0L;eidx <- 0L
  for (session in sort(unique(m$session_id))) {
    z <- m[m$session_id==session,,drop=FALSE]
    cameras <- sort(unique(z$camera_id))
    if (length(cameras)<2L || !reference_camera %in% cameras)
      stop("Each session must contain reference and >=1 other camera",
           call.=FALSE)
    ref <- z[z$camera_id==reference_camera,,drop=FALSE]
    if (!all(all_ids %in% ref$marker_id))
      stop("Reference camera is missing a required independent sync pulse",
           call.=FALSE)
    reference_times <- ref$time_s[match(all_ids,ref$marker_id)]
    # User-specified training and holdout ID vectors are sets, not a
    # chronological sequence. Check physical order by reference time,
    # preserving the original ID-index alignment for estimation.
    physical_order <- order(reference_times)
    if (any(diff(reference_times[physical_order])<=0))
      stop("Selected physical reference pulses must be unique in time",
           call.=FALSE)
    for (cam in cameras) {
      d <- z[z$camera_id==cam,,drop=FALSE]
      if (!all(all_ids %in% d$marker_id))
        stop("Camera ",cam," is missing a required sync pulse",
             call.=FALSE)
      t <- d$time_s[match(all_ids,d$marker_id)]
      if (any(diff(t[physical_order])<=0))
        stop("Matched camera pulses must increase in physical order",
             call.=FALSE)
      train <- seq_along(train_markers)
      hold <- (length(train_markers)+1L):length(all_ids)
      if (cam==reference_camera) {
        intercept <- 0;slope <- 1
      } else {
        fit <- stats::lm(reference_times[train] ~ t[train])
        intercept <- unname(stats::coef(fit)[1L])
        slope <- unname(stats::coef(fit)[2L])
        if (!is.finite(intercept) || !is.finite(slope) || slope<=0)
          stop("Non-identifiable or invalid positive camera clock mapping",
               call.=FALSE)
      }
      predict_time <- intercept+slope*t
      resid <- predict_time-reference_times
      train_rmse <- sqrt(mean(resid[train]^2))
      hold_rmse <- sqrt(mean(resid[hold]^2))
      hold_max <- max(abs(resid[hold]))
      extrapolated <- any(t[hold] < min(t[train]) |
                          t[hold] > max(t[train]))
      cidx <- cidx+1L
      coeff[[cidx]] <- data.frame(
        session_id=session,camera_id=cam,
        reference_camera=reference_camera,
        intercept_s=intercept,slope=slope,
        drift_ppm=(slope-1)*1e6,
        n_training=length(train),n_holdout=length(hold),
        training_rmse_s=train_rmse,
        holdout_rmse_s=hold_rmse,
        holdout_max_abs_s=hold_max,
        holdout_extrapolates=extrapolated,
        within_tolerance=hold_max<=max_holdout_error_s,
        earliest_pulse_s=min(t),latest_pulse_s=max(t))
      for (j in hold) {
        eidx <- eidx+1L
        errors[[eidx]] <- data.frame(
          session_id=session,camera_id=cam,
          marker_id=all_ids[j],time_camera_s=t[j],
          time_reference_s=reference_times[j],
          predicted_reference_s=predict_time[j],
          signed_error_s=resid[j],
          absolute_error_s=abs(resid[j]))
      }
    }
  }
  structure(list(fits=do.call(rbind,coeff),
     holdout=do.call(rbind,errors),
     reference_camera=reference_camera,
     training_markers=train_markers,
     holdout_markers=holdout_markers,
     max_holdout_error_s=max_holdout_error_s,
     pulses_independently_verified=FALSE,
     camera_timing_certified=FALSE,
     tolerance_is_external=TRUE),
     class="aqt_clock_holdout")
}

#' Apply per-session validated clock fits without discarding raw timestamps
#'
#' Rejects failed heldout clock checks by default, all absent
#' camera/session transforms and source times outside the pulse span
#' beyond an explicitly allowed extrapolation margin.
#'
#' @param tracks Validated 2D/3D aqt_tracks.
#' @param fitted aqt_clock_holdout object.
#' @param require_tolerance Reject any failed camera/session holdout.
#' @param max_extrapolation_s Allowed outside-pulse clock seconds;
#'   zero requires all sample times within measured pulse span.
#' @return aqt_tracks with time_raw_s, synchronized time_s and
#'   heldout timing diagnostics attached per observation.
#' @export
aqt_sync_holdout_apply <- function(
    tracks,fitted,require_tolerance=TRUE,max_extrapolation_s=0) {
  aqt_tracks_validate(tracks)
  if (!inherits(fitted,"aqt_clock_holdout") ||
      !is.data.frame(fitted$fits))
    stop("Expected aqt_clock_holdout fit",call.=FALSE)
  if (!is.logical(require_tolerance) ||
      length(require_tolerance)!=1L || is.na(require_tolerance))
    stop("require_tolerance must be a single logical",call.=FALSE)
  if (!is.numeric(max_extrapolation_s) ||
      length(max_extrapolation_s)!=1L ||
      !is.finite(max_extrapolation_s) || max_extrapolation_s<0)
    stop("max_extrapolation_s must be finite nonnegative seconds",
         call.=FALSE)
  d <- as.data.frame(tracks)
  key <- paste(d$session_id,d$camera_id,sep="\r")
  fitkey <- paste(fitted$fits$session_id,
                  fitted$fits$camera_id,sep="\r")
  if (anyDuplicated(fitkey))
    stop("Duplicate affine camera mapping",call.=FALSE)
  idx <- match(key,fitkey)
  if (anyNA(idx))
    stop("No heldout timing fit for a requested camera/session",call.=FALSE)
  f <- fitted$fits[idx,,drop=FALSE]
  if (require_tolerance && any(!f$within_tolerance))
    stop("At least one camera fails heldout synchronization tolerance",
         call.=FALSE)
  excess <- pmax(f$earliest_pulse_s-d$time_s,
                 d$time_s-f$latest_pulse_s,0)
  if (any(excess>max_extrapolation_s))
    stop("Source video timestamps exceed pulse support/extrapolation limit",
         call.=FALSE)
  if ("time_raw_s" %in% names(d))
    stop("Tracks already contain time_raw_s: prevent double clock mapping",
         call.=FALSE)
  d$time_raw_s <- d$time_s
  d$time_s <- f$intercept_s+f$slope*d$time_s
  d$clock_holdout_rmse_s <- f$holdout_rmse_s
  d$clock_holdout_max_abs_s <- f$holdout_max_abs_s
  d$clock_drift_ppm <- f$drift_ppm
  d$clock_extrapolation_s <- excess
  d$clock_within_tolerance <- f$within_tolerance
  answer <- aqt_tracks(
    d,units=attr(tracks,"aqt_units"),
    coordinate_system=attr(tracks,"aqt_coordinate_system"))
  attr(answer,"aqt_clock_pulse_verification") <- FALSE
  attr(answer,"aqt_clock_holdout_tolerance_s") <-
    fitted$max_holdout_error_s
  answer
}
