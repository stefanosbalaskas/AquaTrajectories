#' Show simultaneous observed fish-school positions in physical 3D
#'
#' Creates an rgl snapshot of actual calibrated XYZ positions for one
#' camera/session/time. Camera-local track IDs are labels only; positions
#' are not rendered as anatomical fish meshes. No assumption of a tank
#' boundary, depth axis orientation, or fish welfare is made.
#'
#' @param tracks Calibrated 3D aqt_tracks in tank coordinates.
#' @param session_id,camera_id Identifiers for one sampled group.
#' @param time_s Exact observation time on the synchronized session clock.
#' @param label_ids Whether to show camera/session-local track labels.
#' @return Observed fish positions invisibly; opens an optional rgl scene.
#' @export
aqt_plot_school3d <- function(tracks,session_id,camera_id,time_s,
                              label_ids=TRUE) {
  aqt_tracks_validate(tracks)
  if (!identical(attr(tracks,"aqt_dimension"),3L) ||
      !identical(attr(tracks,"aqt_coordinate_system"),"tank") ||
      !attr(tracks,"aqt_units") %in% c("cm","m"))
    stop("True calibrated 3D tank trajectories are required",call.=FALSE)
  if (!requireNamespace("rgl",quietly=TRUE))
    stop("Install optional rgl for interactive 3D plotting",call.=FALSE)
  if (!is.numeric(time_s) || length(time_s)!=1L || !is.finite(time_s))
    stop("time_s must be one finite timestamp",call.=FALSE)
  if (!is.logical(label_ids) || length(label_ids)!=1L || is.na(label_ids))
    stop("label_ids must be TRUE or FALSE",call.=FALSE)
  d <- .aqt_group_observed(tracks)
  d <- d[d$session_id==session_id & d$camera_id==camera_id &
          d$time_s==time_s,,drop=FALSE]
  if (!nrow(d)) stop("No observed fish in requested 3D frame",call.=FALSE)
  colours <- grDevices::hcl.colors(nrow(d),"Dark 3")
  rgl::plot3d(d$x,d$y,d$z,type="p",size=8,col=colours,
              xlab=paste0("X (",attr(tracks,"aqt_units"),")"),
              ylab=paste0("Y (",attr(tracks,"aqt_units"),")"),
              zlab=paste0("Z (",attr(tracks,"aqt_units"),")"))
  if (label_ids)
    rgl::text3d(d$x,d$y,d$z,texts=d$track_id,
                color=colours,adj=c(0,-.5))
  invisible(d)
}

#' Plot 3D occupancy voxels as an observed-sample point cloud
#'
#' Marker sizes represent relative observed sample frequency in grid cells.
#' This is not a voxel mesh, a continuous dwell-time estimate, or a
#' confidence region for each fish's position.
#'
#' @param voxels Table from aqt_voxel_occupancy, for exactly one group/fish.
#' @return Observed nonempty grid voxels invisibly; opens optional rgl plot.
#' @export
aqt_plot_voxel3d <- function(voxels) {
  need <- c("x_mid","y_mid","z_mid","n_samples",
            "sample_fraction","session_id","camera_id")
  if (!is.data.frame(voxels) || !all(need %in% names(voxels)) ||
      !nrow(voxels))
    stop("Expected nonempty aqt_voxel_occupancy result",call.=FALSE)
  if (!is.numeric(voxels$n_samples) ||
      any(!is.finite(voxels$n_samples)) ||
      any(voxels$n_samples<0) ||
      !is.numeric(voxels$sample_fraction))
    stop("Invalid voxel sample counts or fractions",call.=FALSE)
  ids <- if ("track_id" %in% names(voxels))
    ifelse(is.na(voxels$track_id),"<GROUP>",as.character(voxels$track_id))
    else rep("<GROUP>",nrow(voxels))
  scope <- paste(voxels$session_id,voxels$camera_id,ids,sep="\r")
  if (length(unique(scope))!=1L)
    stop("Plot one session/camera/fish voxel distribution at a time",call.=FALSE)
  d <- voxels[voxels$n_samples>0,,drop=FALSE]
  if (!nrow(d)) stop("No occupied voxels",call.=FALSE)
  if (any(!is.finite(d$sample_fraction)) ||
      any(d$sample_fraction<0 | d$sample_fraction>1) ||
      any(!is.finite(as.matrix(d[,c("x_mid","y_mid","z_mid"),drop=FALSE]))))
    stop("Invalid occupied voxel coordinates or fractions",call.=FALSE)
  if (!requireNamespace("rgl",quietly=TRUE))
    stop("Install optional rgl for 3D voxel graphics",call.=FALSE)
  q <- d$sample_fraction
  pal <- grDevices::hcl.colors(16,"Viridis")
  bins <- pmin(16L,pmax(1L,as.integer(ceiling(q*16))))
  units <- attr(voxels,"aqt_units")
  if (is.null(units)) units <- "source units"
  # rgl::points3d() accepts a vector of colours but requires a SINGLE
  # numeric point size per draw call. Group same-size voxels rather than
  # passing a vector of sizes to plot3d() (which fails on Windows rgl).
  # Render sizes at 0.01 resolution to avoid hundreds of graphics batches.
  sizes <- round(3+20*sqrt(q),digits=2L)
  rgl::plot3d(d$x_mid,d$y_mid,d$z_mid,type="n",
    xlab=paste0("X (",units,")"),ylab=paste0("Y (",units,")"),
    zlab=paste0("Z (",units,")"))
  for (size in unique(sizes)) {
    take <- which(sizes==size)
    rgl::points3d(d$x_mid[take],d$y_mid[take],d$z_mid[take],
                  color=pal[bins[take]],size=as.numeric(size))
  }
  invisible(d)
}

#' Plot observed school geometry over time without frame-level inference
#'
#' A descriptive trajectory of group-level distances and spatial structure.
#' Different fish counts and tracking quality can change the measures.
#'
#' @param summary Table returned by aqt_group_spatial_summary().
#' @param session_id,camera_id One scoped group.
#' @param metric radius_gyration, mean_pair_distance or group_extent.
#' @return Selected group summary invisibly; creates base graphics plot.
#' @export
aqt_plot_school_dynamics <- function(summary,session_id,camera_id,
                                     metric=c("radius_gyration",
                                              "mean_pair_distance",
                                              "group_extent")) {
  metric <- match.arg(metric)
  required <- c("session_id","camera_id","time_s",metric)
  if (!is.data.frame(summary) || !all(required %in% names(summary)))
    stop("Expected valid school geometry summary",call.=FALSE)
  d <- summary[summary$session_id==session_id &
               summary$camera_id==camera_id,,drop=FALSE]
  if (!nrow(d)) stop("No observations for selected group",call.=FALSE)
  d <- d[order(d$time_s),,drop=FALSE]
  if (!is.numeric(d[[metric]]) || any(!is.finite(d[[metric]])))
    stop("Invalid school geometry metric",call.=FALSE)
  units <- attr(summary,"aqt_units")
  if (is.null(units)) units <- "source units"
  graphics::plot(d$time_s,d[[metric]],type="l",lwd=1.5,
    xlab="Recording time (seconds)",
    ylab=paste0(metric," (",units,")"),
    main="Observed fish-school geometry")
  invisible(d)
}
