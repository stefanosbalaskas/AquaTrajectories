#' Estimate 3D spatial occupancy on an explicitly defined voxel grid
#'
#' Counts observed calibrated fish positions inside fixed rectangular
#' voxels. Does not interpolate between samples and does not measure
#' continuous residence time; irregular temporal sampling can bias these
#' sample-based fractions. All out-of-range positions are reported.
#'
#' @param tracks Validated 3D tank-space trajectories.
#' @param breaks Named list of increasing numeric x, y and z break vectors,
#'   in the same world-coordinate units as tracks.
#' @param by fish for per-individual occupancy, or group for shared occupancy
#'   within session/camera.
#' @return One row per voxel and analysis group with n_samples,
#'   sample_fraction, n_valid and n_outside.
#' @export
aqt_voxel_occupancy <- function(tracks,breaks,by=c("group","fish")) {
  aqt_tracks_validate(tracks)
  by <- match.arg(by)
  if (!identical(attr(tracks,"aqt_dimension"),3L) ||
      !identical(attr(tracks,"aqt_coordinate_system"),"tank"))
    stop("Voxel occupancy requires calibrated 3D tank coordinates",call.=FALSE)
  if (!is.list(breaks) || !all(c("x","y","z") %in% names(breaks)))
    stop("Provide named x/y/z voxel break vectors",call.=FALSE)
  for (dim in c("x","y","z")) {
    b <- breaks[[dim]]
    if (!is.numeric(b) || length(b)<2L || any(!is.finite(b)) ||
        any(diff(b)<=0))
      stop("Voxel breaks must be strictly increasing finite numeric",call.=FALSE)
  }
  nx <- length(breaks$x)-1L;ny <- length(breaks$y)-1L
  nz <- length(breaks$z)-1L
  total <- as.double(nx)*ny*nz
  if (!is.finite(total) || total>1e6)
    stop("Voxel grid exceeds safety limit of 1,000,000 cells",call.=FALSE)
  cells <- expand.grid(ix=seq_len(nx),iy=seq_len(ny),iz=seq_len(nz))
  cells$x_mid <- (breaks$x[cells$ix]+breaks$x[cells$ix+1L])/2
  cells$y_mid <- (breaks$y[cells$iy]+breaks$y[cells$iy+1L])/2
  cells$z_mid <- (breaks$z[cells$iz]+breaks$z[cells$iz+1L])/2
  if (!nrow(tracks)) return(data.frame())
  key <- if (by=="fish")
    interaction(tracks$session_id,tracks$camera_id,tracks$track_id,drop=TRUE)
  else interaction(tracks$session_id,tracks$camera_id,drop=TRUE)
  output <- lapply(split(seq_len(nrow(tracks)),key),function(idx) {
    d <- tracks[idx,,drop=FALSE]
    observed <- d$observed &
      stats::complete.cases(d[,c("x","y","z"),drop=FALSE])
    pos <- d[observed,c("x","y","z"),drop=FALSE]
    ix <- findInterval(pos$x,breaks$x,rightmost.closed=TRUE)
    iy <- findInterval(pos$y,breaks$y,rightmost.closed=TRUE)
    iz <- findInterval(pos$z,breaks$z,rightmost.closed=TRUE)
    inside <- ix>=1L & ix<=nx & iy>=1L & iy<=ny & iz>=1L & iz<=nz
    bins <- ix[inside]+nx*(iy[inside]-1L)+nx*ny*(iz[inside]-1L)
    counts <- tabulate(bins,nbins=as.integer(total))
    out <- cells
    out$session_id <- d$session_id[1L]
    out$camera_id <- d$camera_id[1L]
    out$track_id <- if (by=="fish") d$track_id[1L] else NA_character_
    out$n_samples <- counts
    out$n_valid <- nrow(pos)
    out$n_outside <- sum(!inside)
    out$sample_fraction <- if (nrow(pos)) counts/nrow(pos)
                           else rep(NA_real_,length(counts))
    out
  })
  ans <- do.call(rbind,unname(output))
  rownames(ans) <- NULL
  attr(ans,"aqt_units") <- attr(tracks,"aqt_units")
  ans
}

#' Inspect reconstructed 3D trajectory quality using two diagnostic plots
#'
#' Produces a distribution of reprojection RMSE and a distribution of
#' between-camera time skew. These are diagnostics, not metrological proof.
#'
#' @param reconstructed aqt_tracks with stereo QC columns.
#' @return Per-session reconstruction summary invisibly.
#' @export
aqt_plot_reconstruction_qc <- function(reconstructed) {
  quality <- aqt_reconstruction_quality(reconstructed)
  ok <- reconstructed$observed &
    is.finite(reconstructed$reprojection_rmse_px)
  if (!any(ok)) stop("No valid reconstructed samples to plot",call.=FALSE)
  previous <- graphics::par(mfrow=c(1,2))
  on.exit(graphics::par(previous),add=TRUE)
  graphics::hist(reconstructed$reprojection_rmse_px[ok],
    xlab="Reprojection RMSE (pixels)",main="Stereo reprojection",
    col="grey80",border="white")
  graphics::hist(reconstructed$time_skew_s[ok],
    xlab="View time difference (seconds)",main="Camera synchronization",
    col="grey80",border="white")
  invisible(quality)
}
