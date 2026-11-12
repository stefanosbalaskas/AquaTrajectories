# Joint uncertainty as individual 3D draw clouds, not Gaussian ellipsoids.
# This module visualizes conditional measurement sensitivity and must
# never be interpreted as a calibrated posterior or confidence region.

#' Extract time-locked physical fish positions under all joint scenarios
#'
#' Uses the most recent observation in each coherent optical/identity
#' scenario, retaining only finite and explicitly observed XYZ no older
#' than max_age_s. Missing or occluded fish are NOT backfilled.
#' Because discrete fish-ID alternatives can be multimodal, returns every
#' observed XYZ draw rather than fitting an unwarranted Gaussian ellipsoid.
#' Summarizes per-label visibility and marginal coordinate quantiles only.
#'
#' @param scenarios An aqt_joint_refractive_scenarios from the validated
#'   joint pixel/flat-glass/identity scenario generator.
#' @param session_id Exactly one preexisting session/tank recording ID.
#' @param frame_s Requested recording time in seconds.
#' @param max_age_s Maximum permitted age of the last observed fish.
#' @param probs Three increasing marginal descriptive quantiles,
#'   default 5th, 50th, 95th percentiles. NOT confidence limits.
#' @return aqt_joint_scene_cloud with every 3D sample, visibility
#'   counts, optional label assignment-change frequencies and units.
#' @export
aqt_joint_scene_cloud <- function(
    scenarios,session_id,frame_s,max_age_s=.2,probs=c(.05,.5,.95)) {
  if (!inherits(scenarios,"aqt_joint_refractive_scenarios") ||
      !is.list(scenarios$tracks) || !length(scenarios$tracks) ||
      length(scenarios$tracks)>500L)
    stop("Expected 1..500 coherent joint refractive scenario tracks",
         call.=FALSE)
  if (!is.character(session_id) || length(session_id)!=1L ||
      is.na(session_id) || !nzchar(trimws(session_id)))
    stop("session_id must identify a single existing recording",
         call.=FALSE)
  if (!is.numeric(frame_s) || length(frame_s)!=1L ||
      !is.finite(frame_s) ||
      !is.numeric(max_age_s) || length(max_age_s)!=1L ||
      !is.finite(max_age_s) || max_age_s<0)
    stop("frame_s must be finite and max_age_s nonnegative",
         call.=FALSE)
  if (!is.numeric(probs) || length(probs)!=3L ||
      any(!is.finite(probs)) || any(probs<=0) ||
      any(probs>=1) || any(diff(probs)<=0))
    stop("probs must be three increasing interior quantiles",
         call.=FALSE)
  count <- length(scenarios$tracks)
  all_labels <- character()
  samples <- vector("list",count)
  unit <- NULL
  camera <- NULL
  for (i in seq_len(count)) {
    tr <- scenarios$tracks[[i]]
    aqt_tracks_validate(tr)
    if (!identical(attr(tr,"aqt_dimension"),3L) ||
        !identical(attr(tr,"aqt_coordinate_system"),"tank") ||
        !attr(tr,"aqt_units") %in% c("cm","m"))
      stop("All scenario trajectories must have physical tank XYZ",
           call.=FALSE)
    if (is.null(unit)) unit <- attr(tr,"aqt_units")
    if (!identical(unit,attr(tr,"aqt_units")))
      stop("All scenarios must have the same physical position units",
           call.=FALSE)
    d <- as.data.frame(tr)
    d <- d[d$session_id==session_id,,drop=FALSE]
    if (!nrow(d))
      stop("Every scenario must contain the requested session",
           call.=FALSE)
    cams <- unique(d$camera_id)
    if (length(cams)!=1L || (!is.null(camera) &&
                              !identical(camera,cams[1L])))
      stop("All scenarios require one consistent fused 3D camera",
           call.=FALSE)
    camera <- cams[1L]
    all_labels <- union(all_labels,as.character(unique(d$track_id)))
    scene <- aqt_tank_scene_snapshot(
      aqt_tracks(d,units=unit,coordinate_system="tank"),
      frame_s=frame_s,tail_s=0,max_age_s=max_age_s)
    h <- scene$heads
    if (!nrow(h)) next
    if (anyDuplicated(as.character(h$track_id)))
      stop("Multiple fish positions for one assigned label in a draw",
           call.=FALSE)
    h$draw <- as.integer(i)
    if (!"assignment_changed" %in% names(h))
      h$assignment_changed <- FALSE
    if (!is.logical(h$assignment_changed) ||
        anyNA(h$assignment_changed))
      stop("Scenario assignment flags must be logical and complete",
           call.=FALSE)
    samples[[i]] <- h[,c("draw","session_id","camera_id",
      "track_id","time_s","x","y","z","age_s",
      "assignment_changed"),drop=FALSE]
  }
  kept <- Filter(Negate(is.null),samples)
  points <- if (length(kept)) do.call(rbind,unname(kept)) else {
    data.frame(draw=integer(),session_id=character(),
      camera_id=character(),track_id=character(),
      time_s=numeric(),x=numeric(),y=numeric(),
      z=numeric(),age_s=numeric(),assignment_changed=logical())
  }
  rownames(points) <- NULL
  stats <- lapply(sort(all_labels),function(label) {
    d <- points[points$track_id==label,,drop=FALSE]
    n <- nrow(d)
    one <- function(v) {
      if (!length(v))return(rep(NA_real_,3L))
      unname(stats::quantile(v,probs=probs))
    }
    x <- one(d$x);y <- one(d$y);z <- one(d$z)
    data.frame(track_id=label,n_draws=count,
      n_visible=n,visibility_fraction=n/count,
      x_lower=x[1L],x_median=x[2L],x_upper=x[3L],
      y_lower=y[1L],y_median=y[2L],y_upper=y[3L],
      z_lower=z[1L],z_median=z[2L],z_upper=z[3L],
      assignment_changed_fraction_among_visible=
        if(n)mean(d$assignment_changed) else NA_real_,
      stringsAsFactors=FALSE)
  })
  summary <- if(length(stats))do.call(rbind,stats) else data.frame()
  if(nrow(summary))rownames(summary) <- NULL
  structure(list(points=points,summary=summary,
     session_id=session_id,camera_id=camera,frame_s=frame_s,
     max_age_s=max_age_s,n_draws=count,units=unit,
     quantile_probabilities=probs,
     uncertainty_type="conditional user-assumed optical and discrete identity scenarios",
     posterior_claim=FALSE,coverage_calibrated=FALSE,
     multimodality_preserved=TRUE),
    class="aqt_joint_scene_cloud")
}

#' Plot a projected uncertainty scenario cloud without Gaussian assumptions
#'
#' Each 3D sample is plotted as a semi-transparent dot, with marginal
#' median position markers for each identity label. Such medians can
#' lie BETWEEN distinct identity modes; they are not reconstructed fish
#' or estimates of anatomical position in a real video frame.
#'
#' @param cloud aqt_joint_scene_cloud.
#' @param plane XY, XZ or YZ projection of existing physical XYZ.
#' @return Cloud invisibly and creates a base R figure.
#' @export
aqt_plot_joint_scene_cloud <- function(cloud,plane=c("xy","xz","yz")) {
  if (!inherits(cloud,"aqt_joint_scene_cloud") ||
      !is.data.frame(cloud$points) || !is.data.frame(cloud$summary))
    stop("Expected an aqt_joint_scene_cloud",call.=FALSE)
  plane <- match.arg(plane)
  d <- cloud$points
  if (!nrow(d))stop("No observed 3D positions in this scenario frame",
                    call.=FALSE)
  ax <- strsplit(plane,"",fixed=TRUE)[[1L]]
  labels <- sort(unique(d$track_id))
  cols <- grDevices::hcl.colors(length(labels),"Dark 3")
  xlim <- range(d[[ax[1L]]],finite=TRUE)
  ylim <- range(d[[ax[2L]]],finite=TRUE)
  if(diff(xlim)<1e-12)xlim <- xlim+c(-.5,.5)
  if(diff(ylim)<1e-12)ylim <- ylim+c(-.5,.5)
  graphics::plot(d[[ax[1L]]],d[[ax[2L]]],type="n",
     xlim=xlim,ylim=ylim,asp=1,
     xlab=paste0(toupper(ax[1L])," (",cloud$units,")"),
     ylab=paste0(toupper(ax[2L])," (",cloud$units,")"),
     main=paste0("3D scenario cloud | t=",cloud$frame_s,
                 " s | ",cloud$n_draws," draws"))
  for (j in seq_along(labels)) {
    p <- d[d$track_id==labels[j],,drop=FALSE]
    graphics::points(p[[ax[1L]]],p[[ax[2L]]],
      pch=16,cex=.52,col=grDevices::adjustcolor(cols[j],alpha.f=.28))
    med <- cloud$summary[cloud$summary$track_id==labels[j],]
    graphics::points(med[[paste0(ax[1L],"_median")]],
      med[[paste0(ax[2L],"_median")]],pch=4,cex=1.3,
      lwd=2,col=cols[j])
  }
  graphics::legend("topright",legend=labels,
    col=cols,pch=4,bty="n",cex=.75)
  invisible(cloud)
}

#' Visualize real XYZ scenario points in optional rgl
#'
#' @param cloud aqt_joint_scene_cloud.
#' @return Cloud invisibly; opens an optional rgl 3D scene.
#' @export
aqt_plot_joint_scene_cloud3d <- function(cloud) {
  if (!inherits(cloud,"aqt_joint_scene_cloud") ||
      !is.data.frame(cloud$points))
    stop("Expected an aqt_joint_scene_cloud",call.=FALSE)
  if(!nrow(cloud$points))
    stop("No observed 3D positions in this scenario frame",call.=FALSE)
  if(!requireNamespace("rgl",quietly=TRUE))
    stop("Install optional rgl for 3D scenario visualization",
         call.=FALSE)
  d <- cloud$points
  names <- sort(unique(d$track_id))
  cols <- grDevices::hcl.colors(length(names),"Dark 3")
  by_id <- match(d$track_id,names)
  rgl::plot3d(d$x,d$y,d$z,type="s",radius=.015,
    col=grDevices::adjustcolor(cols[by_id],alpha.f=.3),
    xlab=paste0("X (",cloud$units,")"),
    ylab=paste0("Y (",cloud$units,")"),
    zlab=paste0("Z (",cloud$units,")"))
  invisible(cloud)
}
