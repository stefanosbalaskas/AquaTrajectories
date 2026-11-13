#' Visualize conditional position-error trajectories alongside observed fish
#'
#' Shows a small set of simulated path scenarios together with original
#' x/y coordinates. These are hypothetical error-model trajectories, not
#' observed alternative fish paths or calibrated statistical envelopes.
#'
#' @param ensemble An aqt_trajectory_ensemble.
#' @param session_id,camera_id,track_id Full scoped fish identity.
#' @param n_draws Number of scenario trajectories to display (1 to 60).
#' @return Base R plot, invisible selected row indices.
#' @export
aqt_plot_ensemble2d <- function(ensemble,session_id,camera_id,track_id,
                                n_draws=20L) {
  if (!inherits(ensemble,"aqt_trajectory_ensemble"))
    stop("Expected aqt_trajectory_ensemble",call.=FALSE)
  if (length(n_draws)!=1L || !is.numeric(n_draws) ||
      !is.finite(n_draws) || n_draws<1 || n_draws>60 ||
      n_draws!=floor(n_draws))
    stop("n_draws must be an integer from 1 to 60",call.=FALSE)
  tracks <- ensemble$tracks
  idx <- which(tracks$session_id==session_id &
               tracks$camera_id==camera_id &
               tracks$track_id==track_id)
  if (!length(idx)) stop("No fish track in requested scope",call.=FALSE)
  idx <- idx[order(tracks$time_s[idx])]
  n <- min(as.integer(n_draws),dim(ensemble$positions)[3L])
  xs <- ensemble$positions[idx,1L,seq_len(n),drop=FALSE]
  ys <- ensemble$positions[idx,2L,seq_len(n),drop=FALSE]
  xlim <- range(c(xs,tracks$x[idx]),finite=TRUE)
  ylim <- range(c(ys,tracks$y[idx]),finite=TRUE)
  if (!all(is.finite(c(xlim,ylim))))
    stop("No valid positions available",call.=FALSE)
  if (diff(xlim)==0) xlim <- xlim+c(-.5,.5)
  if (diff(ylim)==0) ylim <- ylim+c(-.5,.5)
  graphics::plot(NA_real_,NA_real_,type="n",xlim=xlim,ylim=ylim,asp=1,
    xlab=paste0("X (",attr(tracks,"aqt_units"),")"),
    ylab=paste0("Y (",attr(tracks,"aqt_units"),")"),
    main=paste("Conditional trajectory sensitivity:",track_id))
  scenario_color <- grDevices::adjustcolor("#4477AA",alpha.f=.22)
  for (k in seq_len(n))
    graphics::lines(ensemble$positions[idx,1L,k],
                    ensemble$positions[idx,2L,k],
                    col=scenario_color,lwd=1)
  graphics::lines(tracks$x[idx],tracks$y[idx],
                  col="#222222",lwd=2)
  graphics::legend("topleft",legend=c("Original path","Error scenarios"),
    col=c("#222222",scenario_color),lwd=c(2,1),bty="n")
  invisible(idx)
}

#' Plot conditional 3D fish trajectory ensembles using optional rgl
#'
#' Draws 3D reference and simulated paths for one scoped fish. Requires
#' complete, actual XYZ coordinates and an installed rgl package.
#'
#' @param ensemble An aqt_trajectory_ensemble containing 3D tracks.
#' @param session_id,camera_id,track_id Full scoped fish identity.
#' @param n_draws Number of 3D scenario lines (maximum 30).
#' @return Invisible selected observation indices; creates rgl scene.
#' @export
aqt_plot_ensemble3d <- function(ensemble,session_id,camera_id,track_id,
                                n_draws=10L) {
  if (!inherits(ensemble,"aqt_trajectory_ensemble") ||
      !identical(attr(ensemble$tracks,"aqt_dimension"),3L))
    stop("Requires a 3D aqt_trajectory_ensemble",call.=FALSE)
  if (!requireNamespace("rgl",quietly=TRUE))
    stop("Install optional package rgl for interactive 3D graphics",call.=FALSE)
  if (length(n_draws)!=1L || !is.numeric(n_draws) ||
      !is.finite(n_draws) || n_draws<1 || n_draws>30 ||
      n_draws!=floor(n_draws))
    stop("n_draws must be an integer from 1 to 30",call.=FALSE)
  x <- ensemble$tracks
  idx <- which(x$session_id==session_id &
               x$camera_id==camera_id &
               x$track_id==track_id)
  if (!length(idx)) stop("Unknown scoped fish trajectory",call.=FALSE)
  idx <- idx[order(x$time_s[idx])]
  n <- min(as.integer(n_draws),dim(ensemble$positions)[3L])
  rgl::plot3d(x$x[idx],x$y[idx],x$z[idx],
              type="l",col="#111111",lwd=3,
              xlab=paste0("X (",attr(x,"aqt_units"),")"),
              ylab=paste0("Y (",attr(x,"aqt_units"),")"),
              zlab=paste0("Z (",attr(x,"aqt_units"),")"))
  for (k in seq_len(n)) {
    rgl::lines3d(ensemble$positions[idx,1L,k],
                 ensemble$positions[idx,2L,k],
                 ensemble$positions[idx,3L,k],
                 color="#4477AA",alpha=.15,lwd=1)
  }
  invisible(idx)
}
