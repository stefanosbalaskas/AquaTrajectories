#' Validate a timestamped event table
#' @param data Columns session_id, event_id, start_s, end_s.
#'   Equal start and end times represent a point event.
#' @return Validated event data frame.
#' @export
aqt_event_table <- function(data) {
  if (!is.data.frame(data) ||
      !all(c("session_id","event_id","start_s","end_s") %in% names(data)))
    stop("Missing event columns",call.=FALSE)
  x <- data
  x$session_id <- as.character(x$session_id)
  x$event_id <- as.character(x$event_id)
  if (anyNA(x$session_id) || anyNA(x$event_id) ||
      any(!nzchar(x$session_id)) || any(!nzchar(x$event_id)))
    stop("Missing event identifier",call.=FALSE)
  if (!is.numeric(x$start_s) || !is.numeric(x$end_s) ||
      any(!is.finite(x$start_s)) || any(!is.finite(x$end_s)) ||
      any(x$start_s>x$end_s))
    stop("Invalid event start/end time",call.=FALSE)
  if (anyDuplicated(paste(x$session_id,x$event_id,sep="|")))
    stop("Duplicate event per session",call.=FALSE)
  x$event_type <- ifelse(x$start_s==x$end_s,"point","interval")
  x
}

#' Align trajectories or features with experimental events
#'
#' Overlapping events generate separate rows; no causal interpretation is
#' implied. Time must already be on the same clock as the event log.
#' @param tracks Trajectory or feature data with session_id/time_s.
#' @param events Event table.
#' @param window_s Time relative to onset, inclusive.
#' @return Event-aligned long data frame.
#' @export
aqt_align_events <- function(tracks,events,window_s=c(-Inf,Inf)) {
  if (!is.data.frame(tracks) ||
      !all(c("session_id","time_s") %in% names(tracks)))
    stop("Expected session_id and time_s",call.=FALSE)
  if (length(window_s)!=2L || anyNA(window_s) || window_s[1L]>window_s[2L])
    stop("Invalid relative time window",call.=FALSE)
  e <- aqt_event_table(events)
  if (!nrow(e)) {
    # Preserve a stable output schema even when there are no event records.
    empty <- as.data.frame(tracks)[FALSE,,drop=FALSE]
    empty$event_id <- character()
    empty$event_start_s <- numeric()
    empty$event_end_s <- numeric()
    empty$relative_time_s <- numeric()
    empty$phase <- character()
    return(empty)
  }
  parts <- lapply(seq_len(nrow(e)),function(i) {
    d <- as.data.frame(tracks)[as.character(tracks$session_id)==e$session_id[i],,drop=FALSE]
    # Scalar assignment to a zero-row data.frame errors in base R. Events
    # without matched observations are valid and must yield zero rows.
    n <- nrow(d)
    d$event_id <- rep(e$event_id[i],n)
    d$event_start_s <- rep(e$start_s[i],n)
    d$event_end_s <- rep(e$end_s[i],n)
    d$relative_time_s <- d$time_s-e$start_s[i]
    d <- d[d$relative_time_s>=window_s[1L] &
           d$relative_time_s<=window_s[2L],,drop=FALSE]
    d$phase <- if (nrow(d)) {
      ifelse(d$time_s<e$start_s[i],"before",
        ifelse(d$time_s<=e$end_s[i],"during","after"))
    } else character()
    d
  })
  out <- do.call(rbind,parts)
  rownames(out) <- NULL
  out
}

#' Estimate camera offset and drift from shared sync events
#' @param markers Data frame camera_id, marker_id, time_s.
#' @param reference_camera Camera defining the common clock.
#' @return Table of affine clock mapping coefficients; one marker only
#'   identifies offset, not drift.
#' @export
aqt_sync_fit <- function(markers,reference_camera) {
  if (!is.data.frame(markers) ||
      !all(c("camera_id","marker_id","time_s") %in% names(markers)))
    stop("Missing marker columns",call.=FALSE)
  m <- markers
  m$camera_id <- as.character(m$camera_id)
  m$marker_id <- as.character(m$marker_id)
  if (!is.numeric(m$time_s) || any(!is.finite(m$time_s)) ||
      anyDuplicated(paste(m$camera_id,m$marker_id,sep="|")))
    stop("Invalid or duplicate camera sync markers",call.=FALSE)
  ref <- m[m$camera_id==reference_camera,c("marker_id","time_s"),drop=FALSE]
  if (!nrow(ref)) stop("Missing reference camera markers",call.=FALSE)
  names(ref)[2L] <- "reference_s"
  result <- lapply(unique(m$camera_id),function(cam) {
    d <- merge(m[m$camera_id==cam,c("marker_id","time_s"),drop=FALSE],
               ref,by="marker_id")
    if (!nrow(d)) stop("No matching markers for ",cam,call.=FALSE)
    if (cam==reference_camera) {
      intercept <- 0; slope <- 1; rmse <- 0
    } else if (nrow(d)==1L) {
      intercept <- d$reference_s[1L]-d$time_s[1L]
      slope <- 1; rmse <- NA_real_
    } else {
      if (stats::sd(d$time_s)==0) stop("Nonvarying camera marker time",call.=FALSE)
      fit <- stats::lm(reference_s~time_s,data=d)
      intercept <- unname(stats::coef(fit)[1L])
      slope <- unname(stats::coef(fit)[2L])
      rmse <- sqrt(mean(stats::residuals(fit)^2))
      if (!is.finite(slope) || slope<=0) stop("Invalid clock slope",call.=FALSE)
    }
    data.frame(camera_id=cam,intercept_s=intercept,slope=slope,
               n_markers=nrow(d),rmse_s=rmse,drift_identifiable=nrow(d)>=2L)
  })
  do.call(rbind,result)
}

#' Apply the camera clock transform
#' @param tracks aqt_tracks.
#' @param sync Fit returned by aqt_sync_fit.
#' @return aqt_tracks with transformed time_s.
#' @export
aqt_sync_apply <- function(tracks,sync) {
  aqt_tracks_validate(tracks)
  if (!is.data.frame(sync) ||
      !all(c("camera_id","intercept_s","slope") %in% names(sync)))
    stop("Invalid synchronization fit",call.=FALSE)
  idx <- match(tracks$camera_id,sync$camera_id)
  if (anyNA(idx)) stop("Missing clock transform for camera",call.=FALSE)
  d <- as.data.frame(tracks)
  d$time_s <- sync$intercept_s[idx]+sync$slope[idx]*d$time_s
  if (any(!is.finite(d$time_s))) stop("Nonfinite synchronized time",call.=FALSE)
  aqt_tracks(d,units=attr(tracks,"aqt_units"),
             coordinate_system=attr(tracks,"aqt_coordinate_system"))
}
