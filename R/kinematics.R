#' Timestamp-aware 2D/3D swimming kinematics
#'
#' No missing segment is bridged; derivatives are unsmoothed, so positional
#' noise can strongly affect acceleration and turning estimates.
#' @param tracks Validated aqt_tracks.
#' @param max_gap_s Largest time step eligible for movement calculation.
#' @return Data frame including dt_s, step_distance, vx/vy/vz, speed,
#'   heading_rad, acceleration and turn_rate_rad_s.
#' @export
aqt_kinematics <- function(tracks,max_gap_s=Inf) {
  aqt_tracks_validate(tracks)
  if (length(max_gap_s)!=1L || is.na(max_gap_s) || max_gap_s<=0)
    stop("max_gap_s must be positive",call.=FALSE)
  out <- as.data.frame(tracks)
  n <- nrow(out)
  for (nm in c("dt_s","step_distance","vx","vy","vz","speed",
               "heading_rad","acceleration","turn_rate_rad_s"))
    out[[nm]] <- rep(NA_real_,n)
  if (!n) return(out)
  scoped <- interaction(out$session_id,out$camera_id,out$track_id,drop=TRUE)
  is3d <- identical(attr(tracks,"aqt_dimension"),3L)
  for (idx in split(seq_len(n),scoped)) {
    m <- length(idx)
    if (m<2L) next
    dt <- diff(out$time_s[idx])
    coord_cols <- c("x","y",if (is3d) "z")
    xy <- as.matrix(out[idx,coord_cols,drop=FALSE])
    delta <- xy[-1L,,drop=FALSE]-xy[-m,,drop=FALSE]
    valid <- dt>0 & dt<=max_gap_s &
      out$observed[idx[-1L]] & out$observed[idx[-m]] &
      stats::complete.cases(xy[-1L,,drop=FALSE]) &
      stats::complete.cases(xy[-m,,drop=FALSE])
    distance <- sqrt(rowSums(delta^2))
    distance[!valid] <- NA_real_
    velocity <- delta/dt
    velocity[!valid,] <- NA_real_
    j <- idx[-1L]
    out$dt_s[j] <- dt
    out$step_distance[j] <- distance
    out$vx[j] <- velocity[,1L]
    out$vy[j] <- velocity[,2L]
    if (is3d) out$vz[j] <- velocity[,3L]
    speed <- distance/dt
    out$speed[j] <- speed
    heading <- atan2(velocity[,2L],velocity[,1L])
    heading[is.na(speed) | speed<=0] <- NA_real_
    out$heading_rad[j] <- heading
    if (m>=3L) {
      out$acceleration[idx[3:m]] <- diff(speed)/dt[-1L]
      delta_angle <- diff(heading)
      out$turn_rate_rad_s[idx[3:m]] <-
        atan2(sin(delta_angle),cos(delta_angle))/dt[-1L]
    }
  }
  out
}

#' Per-individual path summaries
#' @param tracks An aqt_tracks object.
#' @param max_gap_s Maximum observed time interval.
#' @return One row per session/camera/track with path length, valid duration,
#'   time-weighted mean speed, and observed fraction.
#' @export
aqt_path_summary <- function(tracks,max_gap_s=Inf) {
  d <- aqt_kinematics(tracks,max_gap_s)
  if (!nrow(d)) return(data.frame())
  groups <- split(seq_len(nrow(d)),
    interaction(d$session_id,d$camera_id,d$track_id,drop=TRUE))
  results <- lapply(groups,function(idx) {
    x <- d[idx,,drop=FALSE]
    ok <- !is.na(x$step_distance)
    length <- sum(x$step_distance[ok])
    duration <- sum(x$dt_s[ok])
    observed <- x$observed & stats::complete.cases(x[,c(
      "x","y",if (identical(attr(tracks,"aqt_dimension"),3L)) "z")])
    data.frame(session_id=x$session_id[1L],camera_id=x$camera_id[1L],
      track_id=x$track_id[1L],n_observations=nrow(x),
      observed_fraction=mean(observed),valid_steps=sum(ok),
      path_length=length,valid_duration_s=duration,
      mean_speed=if (duration>0) length/duration else NA_real_)
  })
  do.call(rbind,unname(results))
}

#' Track QC flags for missing positions, time gaps, and implausible motion
#' @param tracks An aqt_tracks object.
#' @param max_gap_s Maximum expected sample interval.
#' @param max_speed Optional velocity threshold in position units/s.
#' @return Observation-level QC data, not a calibrated error estimate.
#' @export
aqt_track_qc <- function(tracks,max_gap_s,max_speed=NULL) {
  if (length(max_gap_s)!=1L || !is.finite(max_gap_s) || max_gap_s<=0)
    stop("max_gap_s must be positive and finite",call.=FALSE)
  if (!is.null(max_speed) &&
      (length(max_speed)!=1L || !is.finite(max_speed) || max_speed<=0))
    stop("max_speed must be positive and finite",call.=FALSE)
  d <- aqt_kinematics(tracks,max_gap_s=Inf)
  d$missing_position <- is.na(d$x) | is.na(d$y) |
    (identical(attr(tracks,"aqt_dimension"),3L) & is.na(d$z))
  d$large_gap <- !is.na(d$dt_s) & d$dt_s > max_gap_s
  d$implausible_speed <- if (is.null(max_speed)) rep(NA,nrow(d)) else
    !is.na(d$speed) & d$speed > max_speed
  d
}

#' Group cohesion and 2D/3D directional polarization
#'
#' Metrics require simultaneous observations at identical timestamps.
#' Polarization requires at least two valid non-zero velocity vectors.
#' @param tracks An aqt_tracks object.
#' @param max_gap_s Largest movement interval.
#' @return Group metrics per session/camera/timestamp.
#' @export
aqt_group_metrics <- function(tracks,max_gap_s=Inf) {
  d <- aqt_kinematics(tracks,max_gap_s)
  if (!nrow(d)) return(data.frame())
  is3d <- identical(attr(tracks,"aqt_dimension"),3L)
  keys <- interaction(d$session_id,d$camera_id,d$time_s,drop=TRUE)
  result <- lapply(split(seq_len(nrow(d)),keys),function(idx) {
    g <- d[idx,,drop=FALSE]
    coords <- as.matrix(g[,c("x","y",if (is3d) "z"),drop=FALSE])
    coords <- coords[stats::complete.cases(coords) & g$observed,,drop=FALSE]
    n <- nrow(coords)
    centre <- if (n) colMeans(coords) else rep(NA_real_,ncol(coords))
    nearest <- NA_real_
    if (n>=2L) {
      D <- as.matrix(stats::dist(coords))
      diag(D) <- Inf
      nearest <- mean(apply(D,1L,min))
    }
    v <- as.matrix(g[,c("vx","vy",if (is3d) "vz"),drop=FALSE])
    norm <- sqrt(rowSums(v^2))
    good <- stats::complete.cases(v) & is.finite(norm) & norm>0
    pol <- if (sum(good)>=2L) {
      u <- v[good,,drop=FALSE]/norm[good]
      sqrt(sum(colMeans(u)^2))
    } else NA_real_
    data.frame(session_id=g$session_id[1L],camera_id=g$camera_id[1L],
      time_s=g$time_s[1L],n_visible=n,centroid_x=centre[1L],
      centroid_y=centre[2L],centroid_z=if (is3d) centre[3L] else NA_real_,
      mean_nearest_neighbor=nearest,polarization=pol)
  })
  out <- do.call(rbind,unname(result))
  out[order(out$session_id,out$camera_id,out$time_s),,drop=FALSE]
}
