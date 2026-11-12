# Wave 11D — immutable-input checks at the real-video/export handoff.
# SHA-256 is unkeyed: this detects accidental/mixed output files, NOT
# malicious provenance tampering or scientific ground-truth correctness.

#' Read a complete, SHA-256-checked Python video tracking export bundle
#'
#' The optional PyAV/YOLO/ByteTrack runner emits a frame PTS table, an
#' MOTChallenge tracker table, an exact class-ID sidecar and JSON metadata.
#' All outputs must have the same prefix and match their recorded hashes,
#' row counts, source camera/session, frame origin and class-row keys.
#' This refuses partial, mixed-run and silently reordered sidecar files.
#' The source video/model hashes are recorded but are NOT checked unless
#' the user separately provides those files for independent verification.
#'
#' @param directory Directory containing the four completed runner files.
#' @param prefix Safe output prefix passed to the Python video runner.
#' @return aqt_video_bundle, with validated 2D tracks, all acquired
#'   video frames, class sidecar, local source metadata and support audit.
#'   No biological fish classification or camera calibration is certified.
#' @export
aqt_video_bundle_import <- function(directory,prefix) {
  if (!is.character(directory) || length(directory)!=1L ||
      is.na(directory) || !dir.exists(directory))
    stop("directory must be an existing video bundle directory",call.=FALSE)
  if (!is.character(prefix) || length(prefix)!=1L ||
      is.na(prefix) || !grepl("^[A-Za-z0-9_-]+$",prefix))
    stop("prefix must be a safe video bundle identifier",call.=FALSE)
  outputs <- c(frames=paste0(prefix,".frames.csv"),
               mot=paste0(prefix,".mot.txt"),
               classes=paste0(prefix,".classes.csv"),
               metadata=paste0(prefix,".run.json"))
  # file.path() may drop vector names; restore exact file-part keys so
  # locations["metadata"] and locations["mot"] never resolve to NA.
  locations <- stats::setNames(file.path(directory,unname(outputs)),
                               names(outputs))
  if (any(!file.exists(locations) | dir.exists(locations)))
    stop("Missing video bundle component; all four outputs are required",
         call.=FALSE)
  metadata <- tryCatch({
    source_json <- paste(readLines(unname(locations["metadata"]),
                                   warn=FALSE,encoding="UTF-8"),
                         collapse="\n")
    jsonlite::fromJSON(source_json,simplifyVector=FALSE)
  },error=function(e)
    stop("Malformed video run metadata JSON: ",conditionMessage(e),
         call.=FALSE))
  if (!is.list(metadata) ||
      !identical(metadata$schema_version,"1.1") ||
      !identical(metadata$time_source,
        "decoded_video_frame_pts_from_same_buffer_as_model_input") ||
      !identical(metadata$time_s_relative_to_first_frame,TRUE) ||
      !is.numeric(metadata$frame_origin_in_mot) ||
      length(metadata$frame_origin_in_mot)!=1L ||
      !isTRUE(metadata$frame_origin_in_mot==1) ||
      !is.list(metadata$outputs) ||
      !is.list(metadata$output_sha256))
    stop("Incompatible or incomplete video bundle metadata schema",
         call.=FALSE)
  for (nm in names(outputs)) {
    if (!identical(metadata$outputs[[nm]],unname(outputs[nm])))
      stop("Bundle output filenames do not match verified prefix",
           call.=FALSE)
  }
  for (part in c("frames","mot","classes")) {
    ref <- metadata$output_sha256[[part]]
    if (!is.character(ref) || length(ref)!=1L ||
        !grepl("^[a-f0-9]{64}$",ref))
      stop("Missing or malformed SHA-256 for video bundle component",
           call.=FALSE)
    observed <- digest::digest(unname(locations[part]),algo="sha256",
                               file=TRUE)
    if (!identical(unname(observed),ref))
      stop("Video bundle SHA-256 mismatch; possible altered or mixed files",
           call.=FALSE)
  }
  n_frames <- metadata$n_decoded_frames
  n_tracked <- metadata$n_tracked_box_rows
  if (!is.numeric(n_frames) || length(n_frames)!=1L ||
      !is.finite(n_frames) || n_frames<1 ||
      n_frames!=floor(n_frames) ||
      !is.numeric(n_tracked) || length(n_tracked)!=1L ||
      !is.finite(n_tracked) || n_tracked<0 ||
      n_tracked!=floor(n_tracked))
    stop("Invalid decoded frame or tracked box counts",call.=FALSE)
  for (nm in c("session_id","camera_id")) {
    v <- metadata[[nm]]
    if (!is.character(v) || length(v)!=1L || is.na(v) ||
        !nzchar(trimws(v)))
      stop("Runner recording scope must be complete",call.=FALSE)
  }
  frame_raw <- tryCatch(
    utils::read.csv(unname(locations["frames"]),
                    stringsAsFactors=FALSE),
    error=function(e) stop("Invalid runner frame manifest CSV",
                           call.=FALSE))
  if (!identical(names(frame_raw),
      c("session_id","camera_id","frame_id","time_s",
        "width_px","height_px")))
    stop("Unexpected video frame manifest columns",call.=FALSE)
  frames <- aqt_frame_manifest(frame_raw)
  if (nrow(frames)!=n_frames ||
      !identical(as.numeric(frames$frame_id),
                 as.numeric(seq_len(n_frames)-1L)) ||
      !all(frames$session_id==metadata$session_id) ||
      !all(frames$camera_id==metadata$camera_id) ||
      abs(frames$time_s[1L])>1e-8)
    stop("Runner frame count, scope, zero-origin PTS or frame IDs mismatch",
         call.=FALSE)

  sidecar <- tryCatch(
    utils::read.csv(unname(locations["classes"]),
                    stringsAsFactors=FALSE,
                    colClasses=c("numeric","character","character")),
    error=function(e) stop("Invalid video class sidecar CSV",
                           call.=FALSE))
  if (!identical(names(sidecar),c("frame_id","track_id","class_id")))
    stop("Unexpected video class sidecar columns",call.=FALSE)
  # Read same MOT file with the production importer, ensuring even the
  # zero-byte (no fish tracked) case is valid and retains full frame scope.
  mot_path <- unname(locations["mot"])
  if (file.info(mot_path)$size==0) {
    mot <- as.data.frame(matrix(numeric(),nrow=0L,ncol=10L))
  } else {
    mot <- tryCatch(
      utils::read.csv(mot_path,header=FALSE,
        stringsAsFactors=FALSE,
        colClasses=c("numeric","character",rep(NA_character_,8L))),
      error=function(e) stop("Invalid runner MOTChallenge CSV",
                             call.=FALSE))
  }
  if (ncol(mot)!=10L || nrow(mot)!=n_tracked ||
      nrow(sidecar)!=n_tracked)
    stop("MOT, class sidecar and run metadata row counts disagree",
         call.=FALSE)
  if (nrow(mot)) {
    if (!is.numeric(sidecar$frame_id) ||
        any(!is.finite(sidecar$frame_id)) ||
        any(sidecar$frame_id<0 | sidecar$frame_id!=floor(sidecar$frame_id)) ||
        anyNA(sidecar$track_id) || anyNA(sidecar$class_id) ||
        any(!grepl("^[0-9]+$",sidecar$track_id)) ||
        any(!grepl("^[0-9]+$",sidecar$class_id)) ||
        !identical(as.numeric(sidecar$frame_id),
                   as.numeric(mot[[1L]]-1L)) ||
        !identical(as.character(sidecar$track_id),
                   as.character(mot[[2L]])))
      stop("Class sidecar frame/track keys do not match MOT row order",
           call.=FALSE)
  }
  tracks <- aqt_import_mot(
    mot,frames,session_id=metadata$session_id,
    camera_id=metadata$camera_id,frame_origin=1L,
    class_ids=as.character(sidecar$class_id))
  if (nrow(tracks)!=n_tracked)
    stop("Imported fish track count differs from original MOT rows",
         call.=FALSE)
  attr(tracks,"aqt_video_bundle_sha256_verified") <- TRUE
  structure(list(
    frames=frames,tracks=tracks,classes=sidecar,
    support=aqt_mot_support_audit(tracks,frames),
    metadata=metadata,paths=locations,
    output_sha256_verified=TRUE,
    source_video_sha256_verified=FALSE,
    source_weights_sha256_verified=FALSE,
    hardware_exposure_synchronization_certified=FALSE,
    fish_identity_accuracy_certified=FALSE,
    underwater_calibration_certified=FALSE),
    class="aqt_video_bundle")
}

#' Score a verified single-camera bundle on independently annotated frames
#'
#' Requires an explicit frame manifest of ALL fully annotated evaluation
#' frames, including zero-fish frames, plus separately annotated truth
#' detection boxes and point tracks. A sampled annotation schedule is
#' allowed but its coverage is reported and never extrapolated to
#' unannotated frames. No ground truth is generated from the prediction.
#'
#' @param bundle aqt_video_bundle with verified file hashes.
#' @param truth_boxes Independent bounding boxes: session_id,camera_id,
#'   frame_id,class_id,xmin,ymin,xmax,ymax. May be zero rows.
#' @param truth_tracks Independent stable per-video fish identities:
#'   session_id,camera_id,frame_id,track_id,x,y,class_id.
#' @param evaluated_frames ALL fully annotated frame IDs, including
#'   those with no fish. Must be a subset of this video bundle.
#' @param max_position_error_px Positive pixel matching cutoff.
#' @param iou_threshold Detection matching overlap threshold.
#' @param confidence_threshold Detection confidence cutoff.
#' @return aqt_video_annotation_benchmark with per-class and pooled
#'   detection metrics, camera-local identity metrics, independent
#'   annotation coverage, no claims of real-fish validation unless
#'   supplied annotations actually come from independent researchers.
#' @export
aqt_video_bundle_benchmark <- function(
    bundle,truth_boxes,truth_tracks,evaluated_frames,
    max_position_error_px=15,
    iou_threshold=.5,confidence_threshold=.25) {
  if (!inherits(bundle,"aqt_video_bundle") ||
      !identical(bundle$output_sha256_verified,TRUE) ||
      !inherits(bundle$frames,"aqt_frame_manifest") ||
      !inherits(bundle$tracks,"aqt_mot_tracks"))
    stop("Expected a SHA-256-verified aqt_video_bundle",call.=FALSE)
  if (!is.data.frame(evaluated_frames) ||
      !all(c("session_id","camera_id","frame_id") %in%
           names(evaluated_frames)) ||
      !is.numeric(evaluated_frames$frame_id) ||
      any(!is.finite(evaluated_frames$frame_id)) ||
      any(evaluated_frames$frame_id<0 |
          evaluated_frames$frame_id!=floor(evaluated_frames$frame_id)))
    stop("Fully annotated frame IDs must be nonnegative integers",
         call.=FALSE)
  e <- aqt_evaluation_frames(evaluated_frames)
  if (!nrow(e))
    stop("At least one fully annotated evaluation frame is required",
         call.=FALSE)
  manifest <- bundle$frames
  key <- function(z) paste(as.character(z$session_id),
                           as.character(z$camera_id),
                           as.character(z$frame_id),sep="\r")
  if (any(!key(e) %in% key(manifest)))
    stop("Evaluation frame is absent from the decoded video manifest",
         call.=FALSE)
  # The tracking and detection APIs each enforce that truth rows are
  # contained in the declared fully annotated evaluation-frame set.
  g <- aqt_detection_boxes(truth_boxes,role="truth")
  ref <- aqt_tracking_observations(truth_tracks)
  if (any(!key(g) %in% key(e)) ||
      any(!key(ref) %in% key(e)))
    stop("Ground truth lies outside the independent annotation frame set",
         call.=FALSE)
  p <- bundle$tracks
  predicted_boxes <- data.frame(
    session_id=p$session_id,camera_id=p$camera_id,
    frame_id=p$frame_id,class_id=p$class_id,
    xmin=p$bbox_left_px,ymin=p$bbox_top_px,
    xmax=p$bbox_left_px+p$bbox_width_px,
    ymax=p$bbox_top_px+p$bbox_height_px,
    confidence=p$confidence)
  predicted_tracks <- data.frame(
    session_id=p$session_id,camera_id=p$camera_id,
    frame_id=p$frame_id,track_id=p$track_id,
    x=p$x,y=p$y,class_id=p$class_id)
  detections <- aqt_detection_metrics(
    g,predicted_boxes,iou_threshold=iou_threshold,
    confidence_threshold=confidence_threshold,
    evaluated_frames=e)
  identities <- aqt_tracking_metrics(
    ref,predicted_tracks,
    max_distance=max_position_error_px,
    class_aware=TRUE,evaluated_frames=e)
  structure(list(
    detection=detections,
    tracking=identities,
    n_video_frames=nrow(manifest),
    n_evaluated_frames=nrow(e),
    annotated_frame_fraction=nrow(e)/nrow(manifest),
    n_truth_boxes=nrow(g),
    n_truth_track_observations=nrow(ref),
    n_predicted_tracks_in_video=nrow(p),
    evaluated_frames=e,
    independent_annotation_source_required=TRUE,
    independent_annotation_source_verified=FALSE,
    detection_training_holdout_disjoint_verified=FALSE,
    biological_identity_certified=FALSE,
    three_dimensional_position_accuracy_certified=FALSE),
    class="aqt_video_annotation_benchmark")
}
