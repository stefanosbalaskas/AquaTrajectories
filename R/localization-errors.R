#' Extract matched position errors from independent annotated fish tracks
#'
#' Reference and predicted 2D point tracks must use the same physical/image
#' coordinate units and frame IDs. All matches come from the existing
#' scoped, class-aware matching code. Maximum-distance association removes
#' large residuals, potentially truncating estimated error variability.
#'
#' @param truth Independent manually verified point tracks.
#' @param pred Automatic point tracks.
#' @param max_distance Threshold for pairing reference and estimate.
#' @param class_aware Require equal class_id within a match.
#' @param evaluated_frames Explicit manifest of annotated frames (recommended).
#' @return Matched signed x/y residuals and Euclidean errors.
#' @export
aqt_tracking_position_errors <- function(truth,pred,max_distance,
                                         class_aware=TRUE,
                                         evaluated_frames=NULL) {
  gt <- .aqt_filter_evaluation_frames(
    aqt_tracking_observations(truth),evaluated_frames,reference=TRUE)
  pd <- .aqt_filter_evaluation_frames(
    aqt_tracking_observations(pred),evaluated_frames)
  matched <- aqt_tracking_match(gt,pd,max_distance,
             class_aware=class_aware)
  if (!nrow(matched)) {
    matched$error_x <- numeric()
    matched$error_y <- numeric()
    return(matched)
  }
  matched$error_x <- pd$x[matched$pred_row]-gt$x[matched$truth_row]
  matched$error_y <- pd$y[matched$pred_row]-gt$y[matched$truth_row]
  matched
}

#' Summarize empirical localization residuals by camera and session
#'
#' This is descriptive measurement-error QC. Sample SDs from matched boxes
#' are not automatically unbiased estimates of detector noise, because the
#' matching threshold, annotator uncertainty, correlated errors and missed
#' detections can change the residual distribution.
#'
#' @param errors Output of aqt_tracking_position_errors().
#' @return Per-session/camera residual bias, RMSE, SD and number of matches.
#' @export
aqt_tracking_position_error_summary <- function(errors) {
  needed <- c("session_id","camera_id","distance","error_x","error_y")
  if (!is.data.frame(errors) || !all(needed %in% names(errors)))
    stop("Expected matched position error table",call.=FALSE)
  if (!nrow(errors)) return(data.frame())
  if (any(!is.finite(errors$distance)) ||
      any(!is.finite(errors$error_x)) ||
      any(!is.finite(errors$error_y)))
    stop("Position errors must be finite",call.=FALSE)
  keys <- interaction(errors$session_id,errors$camera_id,drop=TRUE)
  results <- lapply(split(seq_len(nrow(errors)),keys),function(idx) {
    z <- errors[idx,,drop=FALSE]
    data.frame(session_id=z$session_id[1L],
      camera_id=z$camera_id[1L],n_matched=nrow(z),
      bias_x=mean(z$error_x),bias_y=mean(z$error_y),
      sd_x=if(nrow(z)>1L) stats::sd(z$error_x) else NA_real_,
      sd_y=if(nrow(z)>1L) stats::sd(z$error_y) else NA_real_,
      rmse_x=sqrt(mean(z$error_x^2)),
      rmse_y=sqrt(mean(z$error_y^2)),
      rmse_2d=sqrt(mean(z$distance^2)))
  })
  out <- do.call(rbind,unname(results))
  rownames(out) <- NULL
  out
}
