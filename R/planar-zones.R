#' Convert 2D image coordinates using an externally measured constant scale
#'
#' This assumes a geometrically valid planar scale. It does NOT correct camera
#' perspective, fish depth, lens distortion or water/glass refraction.
#' The function preserves original source pixel coordinates for auditing.
#' @param tracks Two-dimensional aqt_tracks in image coordinates and pixels.
#' @param pixels_per_cm Positive independently measured scale.
#' @return Calibrated planar aqt_tracks in cm, tank coordinates.
#' @export
aqt_scale_calibrate <- function(tracks,pixels_per_cm) {
  aqt_tracks_validate(tracks)
  if (!identical(attr(tracks,"aqt_dimension"),2L) ||
      !identical(attr(tracks,"aqt_coordinate_system"),"image") ||
      !identical(attr(tracks,"aqt_units"),"px"))
    stop("Requires 2D pixel-space image tracks",call.=FALSE)
  if (length(pixels_per_cm)!=1L || !is.numeric(pixels_per_cm) ||
      !is.finite(pixels_per_cm) || pixels_per_cm<=0)
    stop("pixels_per_cm must be positive and finite",call.=FALSE)
  d <- as.data.frame(tracks)
  d$x_px <- d$x; d$y_px <- d$y
  d$x <- d$x/pixels_per_cm
  d$y <- d$y/pixels_per_cm
  out <- aqt_tracks(d,units="cm",coordinate_system="tank")
  attr(out,"aqt_calibration") <- list(type="planar_scale",
                                     pixels_per_cm=pixels_per_cm)
  out
}

#' Summarize sampled spatial occupancy within user-defined rectangles
#'
#' Uses the proportion of valid sampled positions in each rectangular zone,
#' not a continuous dwell-time estimator. Overlapping zones are permitted and
#' may each contain the same observation. Coordinate units must match tracks.
#' @param tracks Validated 2D or 3D aqt_tracks.
#' @param zones Table with zone_id, xmin, xmax, ymin, ymax and optionally zmin,
#'   zmax; omit z bounds to ignore height even for 3D.
#' @return Per scoped fish and zone, n_valid, n_in_zone, sample_fraction.
#' @export
aqt_zone_occupancy <- function(tracks,zones) {
  aqt_tracks_validate(tracks)
  req <- c("zone_id","xmin","xmax","ymin","ymax")
  if (!is.data.frame(zones) || !all(req %in% names(zones)) || !nrow(zones))
    stop("zones must be a nonempty table of rectangular bounds",call.=FALSE)
  if (anyNA(zones$zone_id) || anyDuplicated(as.character(zones$zone_id)))
    stop("zone_id must be unique and nonmissing",call.=FALSE)
  for (nm in req[-1L]) {
    if (!is.numeric(zones[[nm]]) || any(!is.finite(zones[[nm]])))
      stop("Zone bounds must be finite numeric",call.=FALSE)
  }
  if (any(zones$xmin>=zones$xmax) || any(zones$ymin>=zones$ymax))
    stop("Zone maxima must exceed minima",call.=FALSE)
  depth_bounds <- all(c("zmin","zmax") %in% names(zones))
  if (depth_bounds) {
    if (!identical(attr(tracks,"aqt_dimension"),3L))
      stop("Depth bounds require true 3D observations",call.=FALSE)
    if (any(!is.finite(zones$zmin)) || any(!is.finite(zones$zmax)) ||
        any(zones$zmin>=zones$zmax))
      stop("Invalid depth bounds",call.=FALSE)
  }
  keys <- interaction(tracks$session_id,tracks$camera_id,tracks$track_id,drop=TRUE)
  results <- list()
  n <- 0L
  for (idx in split(seq_len(nrow(tracks)),keys)) {
    d <- tracks[idx,,drop=FALSE]
    valid <- d$observed & !is.na(d$x) & !is.na(d$y)
    if (depth_bounds) valid <- valid & !is.na(d$z)
    n_valid <- sum(valid)
    for (j in seq_len(nrow(zones))) {
      within <- valid & d$x>=zones$xmin[j] & d$x<=zones$xmax[j] &
        d$y>=zones$ymin[j] & d$y<=zones$ymax[j]
      if (depth_bounds) within <- within & d$z>=zones$zmin[j] & d$z<=zones$zmax[j]
      hits <- sum(within,na.rm=TRUE)
      n <- n+1L
      results[[n]] <- data.frame(session_id=d$session_id[1L],
        camera_id=d$camera_id[1L],track_id=d$track_id[1L],
        zone_id=as.character(zones$zone_id[j]),n_valid=n_valid,
        n_in_zone=hits,sample_fraction=if (n_valid) hits/n_valid else NA_real_)
    }
  }
  if (!length(results)) return(data.frame())
  do.call(rbind,results)
}
