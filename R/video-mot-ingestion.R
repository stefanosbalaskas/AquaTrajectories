# Wave 11A: camera-local video frame timing and external tracking-export ingest.
# It does not execute YOLO, ByteTrack, idtracker.ai, ffmpeg or video decoding.

#' Validate an independently exported video frame timing manifest
#'
#' Video timestamps should be actual presentation timestamps (PTS) or a
#' separately verified equivalent, not an inferred frame/fps clock. Frame
#' IDs are always zero-based integers. Gaps are allowed and disclosed;
#' timestamps must increase strictly within each session/camera.
#'
#' @param data Data frame with session_id, camera_id, frame_id, time_s,
#'   width_px and height_px. Include frames with zero fish detections.
#' @return aqt_frame_manifest with exact observed frames and image sizes;
#'   frame PTS, physical camera synchronization and provenance remain
#'   externally verified responsibilities.
#' @export
aqt_frame_manifest <- function(data) {
  fields <- c("session_id","camera_id","frame_id","time_s",
              "width_px","height_px")
  if (!is.data.frame(data) || !all(fields %in% names(data)) ||
      !nrow(data))
    stop("Frame manifest must contain nonempty camera/frame/time/size rows",
         call.=FALSE)
  d <- as.data.frame(data,stringsAsFactors=FALSE)
  for (nm in fields[1:2]) {
    v <- as.character(d[[nm]])
    if (anyNA(v) || any(!nzchar(trimws(v))))
      stop("Frame session/camera identifiers must be complete",call.=FALSE)
    d[[nm]] <- v
  }
  for (nm in fields[3:6]) {
    if (!is.numeric(d[[nm]]) || any(!is.finite(d[[nm]])))
      stop("Frame indices, times and image sizes must be finite numeric",
           call.=FALSE)
  }
  if (any(d$frame_id<0 | d$frame_id!=floor(d$frame_id)) ||
      any(d$time_s<0) ||
      any(d$width_px<1 | d$width_px!=floor(d$width_px)) ||
      any(d$height_px<1 | d$height_px!=floor(d$height_px)))
    stop("Frame IDs must be nonnegative integers; dimensions positive integers and PTS nonnegative",
         call.=FALSE)
  key <- paste(d$session_id,d$camera_id,d$frame_id,sep="\r")
  if (anyDuplicated(key))
    stop("Duplicate frame within camera/session manifest",call.=FALSE)
  d <- d[order(d$session_id,d$camera_id,d$frame_id),,drop=FALSE]
  rownames(d) <- NULL
  groups <- split(seq_len(nrow(d)),paste(d$session_id,d$camera_id,sep="\r"))
  for (i in groups) {
    z <- d[i,,drop=FALSE]
    if (nrow(z)>1L && any(diff(z$time_s)<=0))
      stop("Frame presentation timestamps must strictly increase in frame order",
           call.=FALSE)
    if (length(unique(z$width_px))!=1L ||
        length(unique(z$height_px))!=1L)
      stop("Frame image dimensions must remain constant within recording",
           call.=FALSE)
  }
  class(d) <- c("aqt_frame_manifest","data.frame")
  attr(d,"aqt_clock_source") <- "externally_supplied_per_frame_pts"
  attr(d,"aqt_hardware_synchronization_certified") <- FALSE
  d
}

#' Import MOTChallenge/ByteTrack 2D detections using measured video PTS
#'
#' Interoperability adapter for standard MOTChallenge comma-separated
#' tracker output: frame, id, left, top, width, height, confidence, ...
#' The first seven fields are required; extras are ignored. A ByteTrack
#' result exported in this convention can be read directly, but this
#' function does not execute a detector/tracker or infer fish identities.
#' Frame numbers are converted using frame_origin, typically 1, then
#' mapped to a *complete* video frame manifest (including empty frames).
#' It never uses a nominal FPS to create pseudo-accurate timestamps.
#'
#' @param detections Data frame with >=7 columns in MOTChallenge order,
#'   or a path to headerless comma-separated MOT text.
#' @param frames aqt_frame_manifest with the selected recording.
#' @param session_id,camera_id Nonempty camera-local recording identifiers.
#' @param frame_origin Raw MOT frame number representing frame_id zero;
#'   normally 1. Exact choice must reflect the exporter configuration.
#' @param class_ids Optional per-row species/label vector; otherwise fish.
#'   A track's class must not change without an externally reviewed split.
#' @return aqt_tracks in image pixels with source frame, bounding box,
#'   confidence, class, PTS timing and explicit unqualified provenance.
#' @export
aqt_import_mot <- function(detections,frames,session_id,camera_id,
                           frame_origin=1L,class_ids=NULL) {
  if (!inherits(frames,"aqt_frame_manifest"))
    stop("Expected independently validated aqt_frame_manifest",
         call.=FALSE)
  manifest <- aqt_frame_manifest(as.data.frame(frames))
  for (id in list(session_id,camera_id))
    if (!is.character(id) || length(id)!=1L || is.na(id) ||
        !nzchar(trimws(id)))
      stop("One complete session_id and camera_id required",call.=FALSE)
  if (!is.numeric(frame_origin) || length(frame_origin)!=1L ||
      !is.finite(frame_origin) || frame_origin!=floor(frame_origin) ||
      frame_origin<0)
    stop("frame_origin must be a nonnegative integer",call.=FALSE)
  if (is.character(detections) && length(detections)==1L &&
      !is.na(detections)) {
    if (!file.exists(detections) || dir.exists(detections))
      stop("MOT text path does not exist",call.=FALSE)
    detections <- utils::read.csv(
      detections,header=FALSE,stringsAsFactors=FALSE)
  }
  if (!is.data.frame(detections) || ncol(detections)<7L)
    stop("MOT export requires at least seven positional columns",
         call.=FALSE)
  d <- as.data.frame(detections,stringsAsFactors=FALSE)
  n <- nrow(d)
  camera_frames <- manifest[manifest$session_id==session_id &
      manifest$camera_id==camera_id,,drop=FALSE]
  if (!nrow(camera_frames))
    stop("No manifest for the requested video session and camera",
         call.=FALSE)
  frame <- d[[1L]]
  id <- as.character(d[[2L]])
  left <- d[[3L]]
  top <- d[[4L]]
  width <- d[[5L]]
  height <- d[[6L]]
  confidence <- d[[7L]]
  for (x in list(frame,left,top,width,height,confidence))
    if (!is.numeric(x) || any(!is.finite(x)))
      stop("MOT frame, XYWH and confidence columns must be finite numeric",
           call.=FALSE)
  if (any(frame<frame_origin | frame!=floor(frame)) ||
      anyNA(id) || any(!grepl("^[0-9]+$",id)))
    stop("MOT frame must be integer and track IDs nonnegative numeric strings",
         call.=FALSE)
  if (any(left<0 | top<0 | width<=0 | height<=0))
    stop("MOT boxes must have nonnegative top-left and positive size",
         call.=FALSE)
  if (any(confidence<0 | confidence>1))
    stop("MOT prediction confidence must be within [0,1]",
         call.=FALSE)
  fid <- frame-frame_origin
  idx <- match(fid,camera_frames$frame_id)
  if (anyNA(idx))
    stop("MOT frame is absent from supplied video PTS manifest",
         call.=FALSE)
  if (any(left+width>camera_frames$width_px[idx]+1e-8 |
          top+height>camera_frames$height_px[idx]+1e-8))
    stop("MOT bounding box falls outside recorded image extent",
         call.=FALSE)
  if (is.null(class_ids)) class_ids <- rep("fish",n)
  if (length(class_ids)!=n || anyNA(class_ids) ||
      any(!nzchar(trimws(as.character(class_ids)))))
    stop("class_ids must provide a nonempty label for each MOT observation",
         call.=FALSE)
  class_ids <- as.character(class_ids)
  if (n) {
    by_id <- split(class_ids,id)
    if (any(vapply(by_id,function(z) length(unique(z))!=1L,
                   logical(1L))))
      stop("Species/class may not change within one camera-local track ID",
           call.=FALSE)
  }
  out <- data.frame(
    session_id=rep(session_id,n),camera_id=rep(camera_id,n),
    track_id=id,time_s=camera_frames$time_s[idx],
    x=left+width/2,y=top+height/2,observed=rep(TRUE,n),
    frame_id=fid,mot_frame=frame,
    bbox_left_px=left,bbox_top_px=top,
    bbox_width_px=width,bbox_height_px=height,
    confidence=confidence,class_id=class_ids,
    stringsAsFactors=FALSE)
  result <- aqt_tracks(out,units="px",coordinate_system="image")
  class(result) <- c("aqt_mot_tracks",class(result))
  attr(result,"aqt_timing_source") <- "external_video_pts"
  attr(result,"aqt_tracking_model_validated") <- FALSE
  attr(result,"aqt_fish_identity_certified") <- FALSE
  attr(result,"aqt_video_metadata") <- data.frame(
    session_id=session_id,camera_id=camera_id,
    n_manifest_frames=nrow(camera_frames),
    first_frame=camera_frames$frame_id[1L],
    last_frame=utils::tail(camera_frames$frame_id,1L),
    stringsAsFactors=FALSE)
  result
}

#' Audit tracker support against actual video frame availability
#'
#' Measures missing detections *among acquired video frames* between
#' successive observations of the same camera-local identity; dropped
#' video frames are excluded rather than mislabelled as occlusions.
#' Missing detections alone cannot distinguish occlusion, tracker
#' failure, fish leaving view, or identity swaps.
#'
#' @param tracks aqt_mot_tracks from aqt_import_mot.
#' @param frames The exact aqt_frame_manifest used for import.
#' @return Per-scoped-track acquired-frame support, missed acquired
#'   frames between detections, frame gaps and video time spans.
#' @export
aqt_mot_support_audit <- function(tracks,frames) {
  if (!inherits(tracks,"aqt_mot_tracks") ||
      !all(c("session_id","camera_id","track_id","frame_id",
             "time_s") %in% names(tracks)))
    stop("Expected aqt_mot_tracks",call.=FALSE)
  aqt_tracks_validate(tracks)
  if (!inherits(frames,"aqt_frame_manifest"))
    stop("Expected aqt_frame_manifest",call.=FALSE)
  m <- aqt_frame_manifest(as.data.frame(frames))
  t <- as.data.frame(tracks)
  if (!nrow(t)) return(data.frame())
  keys <- paste(t$session_id,t$camera_id,t$track_id,sep="\r")
  rows <- lapply(split(seq_len(nrow(t)),keys),function(idx) {
    z <- t[idx,,drop=FALSE]
    z <- z[order(z$frame_id),,drop=FALSE]
    f <- m[m$session_id==z$session_id[1L] &
           m$camera_id==z$camera_id[1L],,drop=FALSE]
    ref <- match(z$frame_id,f$frame_id)
    if (!nrow(f) || anyNA(ref) ||
        any(abs(f$time_s[ref]-z$time_s)>1e-8))
      stop("MOT tracks and supplied frame manifest do not match",
           call.=FALSE)
    if (nrow(z)>1L && any(diff(z$frame_id)<=0))
      stop("Repeated/nonincreasing frame within track",call.=FALSE)
    missed <- if (nrow(z)>1L)
      sum(diff(ref)-1L) else 0L
    largest_time_gap <- if (nrow(z)>1L)
      max(diff(z$time_s)) else NA_real_
    data.frame(
      session_id=z$session_id[1L],camera_id=z$camera_id[1L],
      track_id=z$track_id[1L],
      class_id=if("class_id" %in% names(z))z$class_id[1L] else NA_character_,
      n_observations=nrow(z),
      n_acquired_between_endpoints=ref[length(ref)]-ref[1L]+1L,
      n_missing_acquired_between=missed,
      n_absent_frame_numbers_between=
        (z$frame_id[nrow(z)]-z$frame_id[1L]+1L)-
        (ref[length(ref)]-ref[1L]+1L),
      max_inter_observation_s=largest_time_gap,
      first_pts_s=z$time_s[1L],
      last_pts_s=z$time_s[nrow(z)],
      stringsAsFactors=FALSE)
  })
  out <- do.call(rbind,unname(rows))
  rownames(out) <- NULL
  out
}
