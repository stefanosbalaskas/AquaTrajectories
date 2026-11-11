#' Reconstruct 3D from already-matched calibrated pinhole observations
#'
#' Uses DLT. It does not identify corresponding fish across camera views,
#' estimate camera calibration, or correct air/water/glass refraction.
#' @param xy1,xy2 Matched numeric n-by-2 image coordinate matrices.
#' @param P1,P2 Finite numeric 3-by-4 pinhole projection matrices.
#' @return Reconstructed x/y/z, reprojection RMSE and a valid flag.
#' @export
aqt_triangulate_pairs <- function(xy1,xy2,P1,P2) {
  a <- as.matrix(xy1); b <- as.matrix(xy2)
  if (!is.numeric(a) || !is.numeric(b) || ncol(a)!=2L ||
      ncol(b)!=2L || nrow(a)!=nrow(b))
    stop("Expected matched n-by-2 coordinate matrices",call.=FALSE)
  if (!is.matrix(P1) || !is.matrix(P2) ||
      !is.numeric(P1) || !is.numeric(P2) ||
      !identical(dim(P1),c(3L,4L)) || !identical(dim(P2),c(3L,4L)) ||
      any(!is.finite(P1)) || any(!is.finite(P2)))
    stop("Expected finite 3-by-4 projection matrices",call.=FALSE)
  vals <- matrix(NA_real_,nrow(a),4L)
  for (i in seq_len(nrow(a))) {
    if (!all(is.finite(c(a[i,],b[i,])))) next
    A <- rbind(a[i,1L]*P1[3L,]-P1[1L,],
               a[i,2L]*P1[3L,]-P1[2L,],
               b[i,1L]*P2[3L,]-P2[1L,],
               b[i,2L]*P2[3L,]-P2[2L,])
    s <- svd(A)
    if (s$d[3L]<=1e-10*max(s$d) || abs(s$v[4L,4L])<=1e-12) next
    xyz1 <- s$v[,4L]/s$v[4L,4L]
    q1 <- as.vector(P1%*%xyz1)
    q2 <- as.vector(P2%*%xyz1)
    if (abs(q1[3L])<=1e-12 || abs(q2[3L])<=1e-12) next
    projected <- c(q1[1:2]/q1[3L],q2[1:2]/q2[3L])
    vals[i,] <- c(xyz1[1:3],sqrt(mean((projected-c(a[i,],b[i,]))^2)))
  }
  d <- as.data.frame(vals)
  names(d) <- c("x","y","z","reprojection_rmse")
  d$valid <- stats::complete.cases(d[,1:3])
  d
}

#' Plot 2D trajectories
#' @param tracks Validated trajectories.
#' @param ... Passed to graphics::plot.
#' @return Invisibly NULL, creating a base graphics plot.
#' @export
aqt_plot_paths <- function(tracks,...) {
  aqt_tracks_validate(tracks)
  if (!nrow(tracks) || all(is.na(tracks$x)) || all(is.na(tracks$y)))
    stop("No valid positions",call.=FALSE)
  ylim <- range(tracks$y,na.rm=TRUE)
  if (identical(attr(tracks,"aqt_coordinate_system"),"image")) ylim <- rev(ylim)
  graphics::plot(tracks$x,tracks$y,type="n",
    xlab=paste0("X (",attr(tracks,"aqt_units"),")"),
    ylab=paste0("Y (",attr(tracks,"aqt_units"),")"),
    ylim=ylim,asp=1,...)
  keys <- interaction(tracks$session_id,tracks$camera_id,tracks$track_id,drop=TRUE)
  gr <- split(seq_len(nrow(tracks)),keys)
  cols <- grDevices::hcl.colors(length(gr),"Dark 3")
  for (j in seq_along(gr)) {
    d <- tracks[gr[[j]],,drop=FALSE]
    graphics::lines(d$x,d$y,col=cols[j],lwd=1.3)
  }
  invisible(NULL)
}

#' Plot true calibrated 3D trajectories
#' @param tracks Validated 3D tank trajectories.
#' @return Invisibly NULL; opens optional rgl scene.
#' @export
aqt_plot_path3d <- function(tracks) {
  aqt_tracks_validate(tracks)
  if (!identical(attr(tracks,"aqt_dimension"),3L))
    stop("True 3D coordinates required; absent z is not zero depth",call.=FALSE)
  if (!requireNamespace("rgl",quietly=TRUE))
    stop("Optional package rgl is required",call.=FALSE)
  keys <- interaction(tracks$session_id,tracks$camera_id,tracks$track_id,drop=TRUE)
  gr <- split(seq_len(nrow(tracks)),keys)
  cols <- grDevices::hcl.colors(length(gr),"Dark 3")
  rgl::plot3d(0,0,0,type="n",xlab="X",ylab="Y",zlab="Z")
  for (j in seq_along(gr)) {
    d <- tracks[gr[[j]],,drop=FALSE]
    rgl::lines3d(d$x,d$y,d$z,color=cols[j],lwd=2)
  }
  invisible(NULL)
}
