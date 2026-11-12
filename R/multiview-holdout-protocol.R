# Wave 13D combined scientific handoff: physically shared cameras and
# disjoint measured 3D targets. No external human truth/survey is invented.

#' Run heldout clock and surveyed XYZ diagnostics as one multiview experiment
#'
#' Combines aqt_sync_holdout_fit and aqt_target_holdout_benchmark without
#' treating timecode similarity as an independently verified physical
#' exposure pulse, or same-board refraction error as independent ground
#' truth. Every real target trial must name a session/camera pair that has
#' both complete training and physically disjoint heldout sync markers.
#'
#' @param markers Original clock marker table; session_id,camera_id,
#'   marker_id,time_s. Marker correspondence must be independently verified.
#' @param surveyed_targets Original measured target/paired pixel table
#'   following aqt_target_trial_table's external physical XYZ contract.
#' @param cameras Named, previously fitted refractive camera model list.
#' @param reference_camera Reference camera, as found in both tables.
#' @param train_markers,holdout_markers Distinct external marker IDs.
#' @param max_holdout_error_s Prespecified positive clock residual tolerance.
#' @param max_ray_separation Physical ray-distance quality threshold.
#' @param target_units Measured XYZ units, cm or m.
#' @return aqt_multiview_holdout_protocol with heldout timing fits, physical
#'   target accuracy, software qualification flags and independent-source
#'   verification still explicitly outstanding.
#' @export
aqt_multiview_holdout_protocol <- function(
    markers,surveyed_targets,cameras,reference_camera,
    train_markers,holdout_markers,max_holdout_error_s=.005,
    max_ray_separation=Inf,target_units=c("cm","m")) {
  target_units <- match.arg(target_units)
  targets <- aqt_target_trial_table(surveyed_targets,units=target_units)
  clock <- aqt_sync_holdout_fit(
    markers,reference_camera=reference_camera,
    train_markers=train_markers,holdout_markers=holdout_markers,
    max_holdout_error_s=max_holdout_error_s)
  sessions <- unique(as.character(targets$session_id))
  model_cams <- unique(c(as.character(targets$camera_a_id),
                         as.character(targets$camera_b_id)))
  clock_scopes <- unique(paste(clock$fits$session_id,
                              clock$fits$camera_id,sep="\r"))
  needed_scopes <- unique(c(paste(targets$session_id,targets$camera_a_id,
                                  sep="\r"),
                            paste(targets$session_id,targets$camera_b_id,
                                  sep="\r")))
  if (!all(needed_scopes %in% clock_scopes))
    stop("Every target camera/session needs a heldout sync fit",
         call.=FALSE)
  if (!all(sessions %in% clock$fits$session_id) ||
      !reference_camera %in% model_cams)
    stop("Surveyed target sessions need the declared reference camera",
         call.=FALSE)
  target_score <- aqt_target_holdout_benchmark(
    targets,cameras,max_ray_separation=max_ray_separation)
  pass_clock <- all(clock$fits$within_tolerance)
  pass_3d <- all(target_score$per_trial$n_holdout_targets>=3L)
  structure(list(
    clock=clock,underwater_targets=target_score,
    summary=list(n_sessions=length(sessions),
      n_tanks=target_score$summary$n_tanks,
      n_target_trials=target_score$summary$n_trials,
      n_heldout_physical_targets=target_score$summary$n_heldout_targets,
      n_valid_target_reconstructions=target_score$summary$n_valid,
      n_failed_target_reconstructions=target_score$summary$n_invalid,
      heldout_xyz_rmse=target_score$summary$pooled_target_rmse_3d,
      heldout_xyz_units=target_units,
      maximum_heldout_camera_clock_error_s=
        max(clock$holdout$absolute_error_s),
      software_holdout_protocol_pass=pass_clock&&pass_3d),
    pulse_correspondence_verified_by_independent_hardware=FALSE,
    surveyed_target_positions_externally_certified=FALSE,
    camera_calibration_fit_independent_verified=FALSE,
    actual_underwater_physical_accuracy_certified=FALSE,
    cross_view_fish_identity_accuracy_certified=FALSE,
    uncertainty_coverage_independently_calibrated=FALSE,
    source_data_format_and_holdouts_validated=TRUE),
    class="aqt_multiview_holdout_protocol")
}
