#' Publication-style four-panel 3D fish trajectory storyboard
#'
#' Produces a static 2 x 2 axonometric projection of a single observed
#' physical-XYZ fish track. Earlier contiguous movement is grey; two
#' non-overlapping recent windows are light and dark blue. The same
#' physical tank bounds and view are used for all four panels.
#'
#' Segments spanning explicitly missing fish observations or a time gap
#' larger than max_gap_s are not connected or counted in distance.
#' No depth is inferred from 2D pixels. The distance is the sum of
#' observed valid segments, NOT an estimate of unobserved travel.
#' Speed is measured over the most recent valid observed segment, not
#' a smoothed or instantaneous biological velocity. Supplied physical
#' coordinates and any external calibration require separate validation.
#'
#' @param tracks Validated 3D aqt_tracks in physical tank units (cm or m).
#' @param times_s Four strictly increasing timestamps. NULL uses four
#'   equally spaced times across the observed trajectory duration.
#' @param session_id,camera_id,track_id Optional identifiers selecting one
#'   fish scope. Required if input contains multiple scopes.
#' @param recent_s Width (seconds) of each of the two recency bands.
#' @param max_gap_s Largest allowed consecutive observed sampling interval;
#'   Inf permits any gap without an explicit missing row.
#' @param max_age_s Largest allowed age of the last observed position
#'   for showing the current fish head and reporting its latest speed.
#' @param tank_limits Optional list(x=c(min,max),y=c(min,max),z=c(min,max))
#'   in the same physical units as tracks. Without it, visible bounds are
#'   inferred from supplied observed XYZ, not independently measured.
#' @return Invisibly, a four-row data frame with audited per-frame observed
#'   distance, latest valid speed, current-observation status, and counts.
#'   Draws a four-panel static figure on the active base graphics device.
#' @export
aqt_plot_trajectory_storyboard3d <- function(
    tracks,times_s=NULL,session_id=NULL,camera_id=NULL,track_id=NULL,
    recent_s=2,max_gap_s=Inf,max_age_s=.2,tank_limits=NULL) {
  aqt_tracks_validate(tracks)
  units <- attr(tracks,"aqt_units")
  if (!identical(attr(tracks,"aqt_dimension"),3L) ||
      !identical(attr(tracks,"aqt_coordinate_system"),"tank") ||
      !units %in% c("cm","m"))
    stop("Storyboard requires real physical XYZ 3D tank coordinates",
         call.=FALSE)
  if (!nrow(tracks)) stop("No fish observations to plot",call.=FALSE)
  scalar_id <- function(x,name) {
    if (!is.null(x) &&
        (!is.character(x) || length(x)!=1L || is.na(x) ||
         !nzchar(trimws(x))))
      stop(name," must be a nonempty scalar character ID",call.=FALSE)
  }
  scalar_id(session_id,"session_id")
  scalar_id(camera_id,"camera_id")
  scalar_id(track_id,"track_id")
  for (v in list(recent_s,max_gap_s,max_age_s)) {
    if (!is.numeric(v) || length(v)!=1L || is.na(v) || v<0)
      stop("Recency, gap, and age limits must be nonnegative numeric scalars",
           call.=FALSE)
  }
  if (!is.finite(recent_s) || recent_s<=0 ||
      max_gap_s==0)
    stop("recent_s and max_gap_s must be strictly positive",
         call.=FALSE)

  d <- as.data.frame(tracks)
  if (!is.null(session_id))
    d <- d[d$session_id==session_id,,drop=FALSE]
  if (!is.null(camera_id))
    d <- d[d$camera_id==camera_id,,drop=FALSE]
  if (!is.null(track_id))
    d <- d[d$track_id==track_id,,drop=FALSE]
  if (!nrow(d)) stop("Selected 3D fish scope contains no records",call.=FALSE)
  scopes <- unique(d[,c("session_id","camera_id","track_id"),drop=FALSE])
  if (nrow(scopes)!=1L)
    stop("Select exactly one session/camera/track_id for the storyboard",
         call.=FALSE)
  d <- d[order(d$time_s),,drop=FALSE]
  good <- d$observed &
    stats::complete.cases(d[,c("x","y","z"),drop=FALSE])
  if (!any(good))
    stop("No genuine observed XYZ positions in selected fish scope",
         call.=FALSE)
  observed_span <- range(d$time_s[good])
  if (diff(observed_span)<=0)
    stop("Storyboard needs more than one timestamp in observed XYZ",
         call.=FALSE)
  if (is.null(times_s))
    times_s <- seq(observed_span[1L],observed_span[2L],length.out=4L)
  if (!is.numeric(times_s) || length(times_s)!=4L ||
      any(!is.finite(times_s)) || any(diff(times_s)<=0) ||
      any(times_s<observed_span[1L] | times_s>observed_span[2L]))
    stop("times_s must contain four strictly increasing in-range times",
         call.=FALSE)

  if (is.null(tank_limits)) {
    tank_limits <- lapply(d[,c("x","y","z"),drop=FALSE],function(v)
      range(v[good],finite=TRUE))
    for (axis in c("x","y","z")) {
      if (diff(tank_limits[[axis]])==0)
        tank_limits[[axis]] <- tank_limits[[axis]]+c(-.5,.5)
    }
    bounds_from_observations <- TRUE
  } else {
    bounds_from_observations <- FALSE
  }
  if (!is.list(tank_limits) ||
      !setequal(names(tank_limits),c("x","y","z")) ||
      length(tank_limits)!=3L ||
      any(!vapply(tank_limits,function(v)
        is.numeric(v) && length(v)==2L && all(is.finite(v)) &&
        v[1L]<v[2L],logical(1L))))
    stop("tank_limits must contain finite increasing x/y/z physical bounds",
         call.=FALSE)
  for (axis in c("x","y","z"))
    if (any(d[[axis]][good]<tank_limits[[axis]][1L] |
            d[[axis]][good]>tank_limits[[axis]][2L]))
      stop("Observed fish positions lie outside tank_limits: ",axis,
           call.=FALSE)

  n <- nrow(d)
  if (n>1L) {
    delta_t <- diff(d$time_s)
    valid_pair <- good[-n] & good[-1L] &
      delta_t>0 & delta_t<=max_gap_s
    i <- which(valid_pair)
    j <- i+1L
    distance <- sqrt((d$x[j]-d$x[i])^2+
                     (d$y[j]-d$y[i])^2+
                     (d$z[j]-d$z[i])^2)
    segments <- data.frame(i=i,j=j,
      end_s=d$time_s[j],length=distance,
      speed=distance/delta_t[i])
  } else {
    segments <- data.frame(i=integer(),j=integer(),end_s=numeric(),
                           length=numeric(),speed=numeric())
  }
  frame_metrics <- lapply(seq_along(times_s),function(k) {
    t <- times_s[k]
    used <- which(segments$end_s<=t)
    before <- which(d$time_s<=t)
    latest <- if (length(before)) utils::tail(before,1L) else NA_integer_
    current <- length(latest)==1L && !is.na(latest) &&
      good[latest] && t-d$time_s[latest]<=max_age_s
    last_segment <- if (current)
      which(segments$j==latest) else integer(0L)
    data.frame(panel=LETTERS[k],time_s=t,
      latest_segment_speed=if (length(last_segment))
        segments$speed[last_segment[length(last_segment)]] else NA_real_,
      observed_distance=if (length(used))
        sum(segments$length[used]) else 0,
      current_position_observed=current,
      n_contiguous_segments=length(used),
      n_observed_positions=sum(good & d$time_s<=t),
      stringsAsFactors=FALSE)
  })
  summary <- do.call(rbind,frame_metrics)
  summary$session_id <- as.character(scopes$session_id[1L])
  summary$camera_id <- as.character(scopes$camera_id[1L])
  summary$track_id <- as.character(scopes$track_id[1L])
  attr(summary,"aqt_units") <- units
  attr(summary,"tank_bounds_from_observations") <- bounds_from_observations
  attr(summary,"independent_calibration_certified") <- FALSE
  rownames(summary) <- NULL

  # One common physical scale on x/y/z: no fabricated depth and no
  # axis-by-axis rescaling that would distort the tank aspect ratio.
  scale <- max(vapply(tank_limits,diff,numeric(1L)))
  proj <- function(x,y,z) {
    xx <- (x-tank_limits$x[1L])/scale
    yy <- (y-tank_limits$y[1L])/scale
    zz <- (z-tank_limits$z[1L])/scale
    cbind(px=xx-.55*yy,py=.18*xx+.43*yy+1.04*zz)
  }
  boxpoints <- expand.grid(x=tank_limits$x,y=tank_limits$y,
                           z=tank_limits$z)
  boxxy <- proj(boxpoints$x,boxpoints$y,boxpoints$z)
  xspan <- range(boxxy[,1L]);yspan <- range(boxxy[,2L])
  xpad <- max(diff(xspan)*.17,.05)
  ypad <- max(diff(yspan)*.16,.05)
  full_xy <- proj(d$x,d$y,d$z)
  drawline <- function(a,b,col,lwd=1) {
    aa <- proj(a[1L],a[2L],a[3L])
    bb <- proj(b[1L],b[2L],b[3L])
    graphics::segments(aa[1L,1L],aa[1L,2L],
                       bb[1L,1L],bb[1L,2L],col=col,lwd=lwd)
  }
  drawgrid <- function() {
    x <- tank_limits$x;y <- tank_limits$y;z <- tank_limits$z
    pale <- "#E0E4E8"
    for (f in c(.25,.5,.75)) {
      xf <- x[1L]+f*diff(x); yf <- y[1L]+f*diff(y)
      zf <- z[1L]+f*diff(z)
      drawline(c(xf,y[1L],z[1L]),c(xf,y[2L],z[1L]),pale)
      drawline(c(x[1L],yf,z[1L]),c(x[2L],yf,z[1L]),pale)
      drawline(c(xf,y[2L],z[1L]),c(xf,y[2L],z[2L]),pale)
      drawline(c(x[1L],y[2L],zf),c(x[2L],y[2L],zf),pale)
      drawline(c(x[2L],yf,z[1L]),c(x[2L],yf,z[2L]),pale)
      drawline(c(x[2L],y[1L],zf),c(x[2L],y[2L],zf),pale)
    }
    for (a in seq_len(7L)) for (b in seq.int(a+1L,8L)) {
      pa <- as.numeric(unlist(boxpoints[a,c("x","y","z")],use.names=FALSE))
      pb <- as.numeric(unlist(boxpoints[b,c("x","y","z")],use.names=FALSE))
      if (sum(pa!=pb)==1L)drawline(pa,pb,"#B7BEC6",1)
    }
    px <- proj(mean(x),y[1L],z[1L])
    py <- proj(x[1L],mean(y),z[1L])
    pz <- proj(x[2L],y[2L],mean(z))
    graphics::text(px[1L,1L],px[1L,2L]-.075,
                   paste0("X: ",format(diff(x),digits=4), " ",units),cex=.66)
    graphics::text(py[1L,1L]-.07,py[1L,2L],
                   paste0("Y: ",format(diff(y),digits=4), " ",units),cex=.66)
    graphics::text(pz[1L,1L]+.085,pz[1L,2L],
                   paste0("Z: ",format(diff(z),digits=4), " ",units),cex=.66)
  }

  oldpar <- graphics::par(no.readonly=TRUE)
  on.exit(graphics::par(oldpar),add=TRUE)
  graphics::par(mfrow=c(2L,2L),mar=c(2.8,2.1,3.2,2.2),
                oma=c(0,0,0,0))
  for (k in seq_along(times_s)) {
    t <- times_s[k]
    graphics::plot(NA_real_,NA_real_,type="n",axes=FALSE,asp=1,
                   xlim=xspan+c(-xpad,xpad),
                   ylim=yspan+c(-ypad,ypad),
                   xlab="",ylab="")
    drawgrid()
    visible_segments <- which(segments$end_s<=t)
    if (length(visible_segments)) {
      endtime <- segments$end_s[visible_segments]
      band <- ifelse(endtime>t-recent_s,3L,
              ifelse(endtime>t-2*recent_s,2L,1L))
      colors <- c("#B4BBC3","#5DC2ED","#153B87")
      for (group in 1:3) {
        selected <- visible_segments[band==group]
        for (s in selected)
          graphics::segments(full_xy[segments$i[s],1L],
                             full_xy[segments$i[s],2L],
                             full_xy[segments$j[s],1L],
                             full_xy[segments$j[s],2L],
                             col=colors[group],lwd=if (group==3L) 2.5 else 1.4)
      }
    }
    last <- which(d$time_s<=t)
    if (length(last)) {
      i <- utils::tail(last,1L)
      if (good[i] && t-d$time_s[i]<=max_age_s)
        graphics::points(full_xy[i,1L],full_xy[i,2L],
                         pch=16,cex=.75,col="#153B87")
    }
    speed <- summary$latest_segment_speed[k]
    speed_label <- if (is.finite(speed))
      sprintf("%.2f %s/s",speed,units) else "not estimable"
    graphics::mtext(sprintf("(%s) Time: %.2f s",LETTERS[k],t),
                    side=3,line=1.6,adj=0,font=2,cex=.83)
    graphics::mtext(sprintf("Speed: %s   Observed distance: %.2f %s",
                  speed_label,summary$observed_distance[k],units),
                  side=3,line=.45,adj=0,cex=.66)
  }
  invisible(summary)
}
