# Three-dimensional, event-aware aquatic tank scene primitives.
# These functions visualize already measured XYZ; never infer depth from 2D.

#' Snapshot verified XYZ fish positions and unbridged recent movement
#'
#' Selects the LAST recorded fish observation at or before the requested
#' frame. A fish is visible only if that LAST observation is observed,
#' fully finite and at most max_age_s old; earlier positions are NEVER
#' silently reused after an explicitly missing observation.
#' Recent tail segments are split at missed frames and long timestamp
#' intervals. Source camera/identity metadata remains in the heads.
#'
#' @param tracks Validated, measured XYZ 3D tank coordinates from one
#'   session and one fused camera. No 2D depth approximation permitted.
#' @param frame_s Snapshot time in session-clock seconds.
#' @param tail_s Past seconds to display as recent fish tracks.
#' @param max_age_s Largest permissible age of the most recent measured fish.
#' @param max_gap_s Largest contiguous observed tail interval.
#' @param events Optional canonical external event table.
#' @return aqt_tank_scene holding visible heads, segmented observed tails,
#'   currently active and recently logged event IDs and units.
#' @export
aqt_tank_scene_snapshot <- function(
    tracks,frame_s,tail_s=3,max_age_s=.2,max_gap_s=.2,events=NULL) {
  aqt_tracks_validate(tracks)
  if (!identical(attr(tracks,"aqt_dimension"),3L) ||
      !identical(attr(tracks,"aqt_coordinate_system"),"tank") ||
      !attr(tracks,"aqt_units") %in% c("cm","m"))
    stop("Tank scenes require measured physical XYZ tracks",call.=FALSE)
  if (!nrow(tracks) || length(unique(tracks$session_id))!=1L ||
      length(unique(tracks$camera_id))!=1L)
    stop("Select one session and one fused 3D camera per tank scene",
         call.=FALSE)
  for (v in list(frame_s,tail_s,max_age_s,max_gap_s))
    if (!is.numeric(v) || length(v)!=1L || !is.finite(v))
      stop("Frame and scene times must be finite numeric scalars",call.=FALSE)
  if (tail_s<0 || max_age_s<0 || max_gap_s<=0)
    stop("tail_s and max_age_s must be nonnegative, max_gap_s positive",
         call.=FALSE)
  session <- as.character(tracks$session_id[1L])
  camera <- as.character(tracks$camera_id[1L])
  d <- as.data.frame(tracks)
  groups <- split(seq_len(nrow(d)),as.character(d$track_id))
  heads <- list();tails <- list();h <- 0L;k <- 0L
  for (idx in groups) {
    one <- d[idx,,drop=FALSE]
    one <- one[order(one$time_s),,drop=FALSE]
    before <- one[one$time_s<=frame_s,,drop=FALSE]
    if (!nrow(before)) next
    latest <- before[nrow(before),,drop=FALSE]
    good <- function(x) x$observed &
      stats::complete.cases(x[,c("x","y","z"),drop=FALSE])
    if (!good(latest) ||
        frame_s-latest$time_s>max_age_s) next
    h <- h+1L
    latest$age_s <- frame_s-latest$time_s
    heads[[h]] <- latest
    if (tail_s==0)next
    recent <- before[before$time_s>=frame_s-tail_s,,drop=FALSE]
    if (!nrow(recent))next
    valid <- good(recent)
    segment <- rep(NA_integer_,nrow(recent))
    number <- 0L
    for (j in seq_len(nrow(recent))) {
      if (!valid[j])next
      if (j==1L || !valid[j-1L] ||
          recent$time_s[j]-recent$time_s[j-1L]>max_gap_s)
        number <- number+1L
      segment[j] <- number
    }
    use <- which(valid)
    if (length(use)) {
      k <- k+1L
      part <- recent[use,,drop=FALSE]
      part$segment_id <- segment[use]
      tails[[k]] <- part
    }
  }
  head <- if (h) do.call(rbind,heads) else d[FALSE,,drop=FALSE]
  tail <- if (k) do.call(rbind,tails) else d[FALSE,,drop=FALSE]
  if (!"age_s" %in% names(head))head$age_s <- numeric(0L)
  if (!"segment_id" %in% names(tail))tail$segment_id <- integer(0L)
  rownames(head) <- rownames(tail) <- NULL
  active <- recent_event <- character()
  if (!is.null(events)) {
    e <- aqt_event_table(events)
    e <- e[e$session_id==session,,drop=FALSE]
    active <- as.character(e$event_id[
      e$start_s<=frame_s & e$end_s>=frame_s])
    recent_event <- as.character(e$event_id[
      e$start_s<=frame_s & e$start_s>=frame_s-tail_s])
  }
  structure(list(
    heads=head,tails=tail,session_id=session,camera_id=camera,
    frame_s=frame_s,tail_s=tail_s,
    units=attr(tracks,"aqt_units"),dimension=3L,
    active_events=unique(active),recent_events=unique(recent_event),
    n_visible=nrow(head),calibration_certified=FALSE,
    measurement_uncertainty_displayed=FALSE,
    interpretation="measured-observation 3D scene; invisible fish and tracking gaps not imputed"),
    class="aqt_tank_scene")
}

#' Assemble bounded time-ordered 3D tank storyboard frames
#'
#' @param tracks A validated single-session 3D tank trajectory.
#' @param times_s Increasing finite requested clock timestamps, 1..200 frames.
#' @param tail_s,max_age_s,max_gap_s As in aqt_tank_scene_snapshot.
#' @param events Optional event log.
#' @return List of aqt_tank_scene objects keyed by frame clock time.
#' @export
aqt_tank_scene_storyboard <- function(tracks,times_s,tail_s=3,
                                      max_age_s=.2,max_gap_s=.2,
                                      events=NULL) {
  if (!is.numeric(times_s) || length(times_s)<1L ||
      length(times_s)>200L || any(!is.finite(times_s)) ||
      any(diff(times_s)<=0))
    stop("times_s must contain 1..200 strictly increasing finite frames",
         call.=FALSE)
  out <- lapply(times_s,function(t)aqt_tank_scene_snapshot(
    tracks,frame_s=t,tail_s=tail_s,max_age_s=max_age_s,
    max_gap_s=max_gap_s,events=events))
  names(out) <- format(times_s,scientific=FALSE,trim=TRUE)
  class(out) <- c("aqt_tank_storyboard","list")
  out
}

#' Plot an orthographic XY/XZ/YZ projection of a measured 3D fish scene
#'
#' All three 2D projections use REAL XYZ coordinates rather than inventing
#' a missing depth. Draws only contiguous observed tail segments.
#' @param scene Output of aqt_tank_scene_snapshot().
#' @param plane One of xy, xz, yz.
#' @return Scene invisibly and generates a base R plot.
#' @export
aqt_plot_tank_projection <- function(scene,plane=c("xy","xz","yz")) {
  if (!inherits(scene,"aqt_tank_scene"))
    stop("Expected aqt_tank_scene",call.=FALSE)
  plane <- match.arg(plane)
  axes <- strsplit(plane,"",fixed=TRUE)[[1L]]
  h <- scene$heads
  tails <- scene$tails
  if (!nrow(h))
    stop("No verified fish positions at this frame",call.=FALSE)
  values <- rbind(h[,axes,drop=FALSE],tails[,axes,drop=FALSE])
  limits <- lapply(axes,function(x) {
    lim <- range(values[[x]],finite=TRUE)
    if (diff(lim)<1e-8)lim <- lim+c(-.5,.5)
    lim
  })
  title <- paste0("Aquatic tank | t=",format(scene$frame_s),
                  " s | ",scene$n_visible," visible fish")
  if(length(scene$active_events))
    title <- paste0(title," | ",paste(scene$active_events,collapse=", "))
  graphics::plot(h[[axes[1L]]],h[[axes[2L]]],
     xlim=limits[[1]],ylim=limits[[2]],
     xlab=paste0(toupper(axes[1L])," (",scene$units,")"),
     ylab=paste0(toupper(axes[2L])," (",scene$units,")"),
     main=title,pch=16,asp=1)
  if (nrow(tails)) {
    keys <- paste(tails$track_id,tails$segment_id,sep="\r")
    for (idx in split(seq_len(nrow(tails)),keys)) {
      p <- tails[idx,,drop=FALSE]
      p <- p[order(p$time_s),,drop=FALSE]
      if (nrow(p)>=2L)
        graphics::lines(p[[axes[1L]]],p[[axes[2L]]],
                        col="#28657D",lwd=1.5)
    }
    graphics::points(h[[axes[1L]]],h[[axes[2L]]],
                     pch=16,col="#B74D31")
  }
  invisible(scene)
}

#' Display 3D fish scene with optional rgl graphics
#'
#' Requires rgl. The output is a scene of existing measured points and
#' gap-separated movement tails, not fish video playback or calibrated
#' confidence volumes.
#' @param scene aqt_tank_scene with currently visible fish.
#' @return Scene invisibly and opens an rgl visualization.
#' @export
aqt_plot_tank_scene3d <- function(scene) {
  if (!inherits(scene,"aqt_tank_scene") ||
      !identical(scene$dimension,3L))
    stop("Expected a physical 3D aqt_tank_scene",call.=FALSE)
  if (!nrow(scene$heads))
    stop("No verified fish positions at this frame",call.=FALSE)
  if (!requireNamespace("rgl",quietly=TRUE))
    stop("Optional rgl package required for 3D fish scenes",call.=FALSE)
  h <- scene$heads
  rgl::plot3d(h$x,h$y,h$z,type="s",radius=.04,
    col="#B74D31",xlab=paste0("X (",scene$units,")"),
    ylab=paste0("Y (",scene$units,")"),
    zlab=paste0("Z (",scene$units,")"))
  tails <- scene$tails
  if (nrow(tails)) {
    keys <- paste(tails$track_id,tails$segment_id,sep="\r")
    for (idx in split(seq_len(nrow(tails)),keys)) {
      p <- tails[idx,,drop=FALSE]
      p <- p[order(p$time_s),,drop=FALSE]
      if(nrow(p)>=2L)rgl::lines3d(p$x,p$y,p$z,
                                  col="#28657D",lwd=2)
    }
  }
  invisible(scene)
}
