#' Declare the video frames covered by manual ground-truth annotation
#'
#' A reference dataset may annotate only sampled video frames. Evaluation
#' must never interpret predictions on unannotated frames as false positives.
#' Include frames with zero fish to score false positives on empty frames.
#'
#' @param data Data frame with session_id, camera_id, frame_id.
#' @return Unique ordered frame manifest.
#' @export
aqt_evaluation_frames <- function(data) {
  needed <- c("session_id","camera_id","frame_id")
  .aqt_required(data,needed,"data")
  d <- as.data.frame(data[,needed,drop=FALSE])
  for (nm in needed) {
    if (anyNA(d[[nm]]) || any(!nzchar(as.character(d[[nm]]))))
      stop("Evaluation frame identifiers cannot be missing",call.=FALSE)
    d[[nm]] <- as.character(d[[nm]])
  }
  if (anyDuplicated(paste(d$session_id,d$camera_id,d$frame_id,sep="\r")))
    stop("Duplicate evaluated frame",call.=FALSE)
  d
}

.aqt_filter_evaluation_frames <- function(d,evaluated_frames,reference=FALSE) {
  if (is.null(evaluated_frames)) return(d)
  f <- aqt_evaluation_frames(evaluated_frames)
  source_key <- paste(d$session_id,d$camera_id,as.character(d$frame_id),sep="\r")
  valid_key <- paste(f$session_id,f$camera_id,f$frame_id,sep="\r")
  included <- source_key %in% valid_key
  if (reference && any(!included))
    stop("Reference annotations outside evaluated_frames manifest",call.=FALSE)
  d[included,,drop=FALSE]
}
