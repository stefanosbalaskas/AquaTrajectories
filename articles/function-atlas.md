# Atlas of all 163 R functions

## Complete R function atlas

Every public R function in this development branch is documented by its
generated `.Rd` help page. This atlas is a **navigation map** rather
than a second implementation of API documentation. Each link opens the
current pkgdown-rendered function reference, including the authoritative
arguments, value description and examples drawn from the package source.

**Coverage:** 163 exported functions in 14 mutually exclusive research
families. An automated website build audit compares the reference index
against `NAMESPACE` and verifies that an `.Rd` manual exists for every
export.

[Browse the reference
index](https://stefanosbalaskas.github.io/AquaTrajectories/reference/index.md)
· [Workflow
atlas](https://stefanosbalaskas.github.io/AquaTrajectories/articles/workflows-atlas.md)
· [Scientific
limitations](https://stefanosbalaskas.github.io/AquaTrajectories/articles/scientific-status.md)

### 1. Data models, import and export (15)

Canonical track objects, synthetic examples and interoperable data
formats.

- [`aqt_export_csv()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_export_csv.md)
- [`aqt_frame_manifest()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_frame_manifest.md)
- [`aqt_import_csv()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_import_csv.md)
- [`aqt_import_idtracker()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_import_idtracker.md)
- [`aqt_import_mot()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_import_mot.md)
- [`aqt_import_yolo()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_import_yolo.md)
- [`aqt_mot_support_audit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_mot_support_audit.md)
- [`aqt_research_bundle_export()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_research_bundle_export.md)
- [`aqt_research_bundle_import()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_research_bundle_import.md)
- [`aqt_research_analyze()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_research_analyze.md)
- [`aqt_research_export()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_research_export.md)
- [`aqt_simulate_tracks()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_simulate_tracks.md)
- [`aqt_tracks()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tracks.md)
- [`aqt_tracks_validate()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tracks_validate.md)
- [`aqt_video_bundle_import()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_video_bundle_import.md)

### 2. Detection, tracking and annotation validation (20)

Detector and identity metrics against explicitly defined reference
annotations.

- [`aqt_3dzef_agreement_import()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_3dzef_agreement_import.md)
- [`aqt_annotation_frame_plan()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_annotation_frame_plan.md)
- [`aqt_annotation_plan_audit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_annotation_plan_audit.md)
- [`aqt_apply_identity_corrections()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_apply_identity_corrections.md)
- [`aqt_box_iou()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_box_iou.md)
- [`aqt_detection_ap()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_ap.md)
- [`aqt_detection_boxes()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_boxes.md)
- [`aqt_detection_map()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_map.md)
- [`aqt_detection_match()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_match.md)
- [`aqt_detection_metrics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_metrics.md)
- [`aqt_evaluation_frames()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_evaluation_frames.md)
- [`aqt_track_qc()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_track_qc.md)
- [`aqt_trajectory_qc()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_trajectory_qc.md)
- [`aqt_qc_review()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_qc_review.md)
- [`aqt_qc_derive()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_qc_derive.md)
- [`aqt_qc_report()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_qc_report.md)
- [`aqt_tracking_match()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tracking_match.md)
- [`aqt_tracking_metrics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tracking_metrics.md)
- [`aqt_tracking_observations()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tracking_observations.md)
- [`aqt_video_bundle_benchmark()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_video_bundle_benchmark.md)

### 3. Camera calibration, optics and synchronization (20)

Projection rigs, camera-clock diagnostics, Brown distortion and
refractive optics.

- [`aqt_brown_camera()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_brown_camera.md)
- [`aqt_brown_distort_pixels()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_brown_distort_pixels.md)
- [`aqt_brown_undistort_pixels()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_brown_undistort_pixels.md)
- [`aqt_brown_undistort_tracks()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_brown_undistort_tracks.md)
- [`aqt_flatport_camera()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_flatport_camera.md)
- [`aqt_flatport_rays()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_flatport_rays.md)
- [`aqt_flatport_rays_distorted()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_flatport_rays_distorted.md)
- [`aqt_flatport_refine_center()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_flatport_refine_center.md)
- [`aqt_refractive_camera()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_camera.md)
- [`aqt_refractive_landmark_qc()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_landmark_qc.md)
- [`aqt_refractive_rays()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_rays.md)
- [`aqt_rig_baseline()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_rig_baseline.md)
- [`aqt_rig_new()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_rig_new.md)
- [`aqt_rig_project()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_rig_project.md)
- [`aqt_rig_validate()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_rig_validate.md)
- [`aqt_scale_calibrate()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_scale_calibrate.md)
- [`aqt_sync_apply()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sync_apply.md)
- [`aqt_sync_fit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sync_fit.md)
- [`aqt_sync_holdout_apply()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sync_holdout_apply.md)
- [`aqt_sync_holdout_fit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sync_holdout_fit.md)

### 4. 3D reconstruction and cross-camera association (14)

Geometric fish association, abstentions, triangulation and
reconstruction quality.

- [`aqt_auto_refractive_pipeline()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_auto_refractive_pipeline.md)
- [`aqt_candidate_rank()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_candidate_rank.md)
- [`aqt_correspondences_from_review()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_correspondences_from_review.md)
- [`aqt_crossview_auto_associate()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_crossview_auto_associate.md)
- [`aqt_multiview_global_fuse()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_multiview_global_fuse.md)
- [`aqt_multiview_holdout_protocol()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_multiview_holdout_protocol.md)
- [`aqt_reconstruct_3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_reconstruct_3d.md)
- [`aqt_reconstruction_quality()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_reconstruction_quality.md)
- [`aqt_refractive_reconstruct_tracks()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_reconstruct_tracks.md)
- [`aqt_refractive_track_quality()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_track_quality.md)
- [`aqt_refractive_triangulate()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_triangulate.md)
- [`aqt_refractive_view_candidates()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_view_candidates.md)
- [`aqt_triangulate_pairs()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_triangulate_pairs.md)
- [`aqt_view_candidates()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_view_candidates.md)

### 5. Movement, schooling and space (11)

Kinematics, 2D/3D school geometry, occupancy and observed scene
snapshots.

- [`aqt_group_metrics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_group_metrics.md)
- [`aqt_group_pairwise_distances()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_group_pairwise_distances.md)
- [`aqt_group_spatial_edges()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_group_spatial_edges.md)
- [`aqt_group_spatial_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_group_spatial_summary.md)
- [`aqt_kinematics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_kinematics.md)
- [`aqt_path_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_path_summary.md)
- [`aqt_tank_scene_snapshot()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tank_scene_snapshot.md)
- [`aqt_tank_scene_storyboard()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tank_scene_storyboard.md)
- [`aqt_voxel_entropy()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_voxel_entropy.md)
- [`aqt_voxel_occupancy()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_voxel_occupancy.md)
- [`aqt_zone_occupancy()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_zone_occupancy.md)

### 6. Events, tank replication and inference (5)

Experimental-event alignment and independently replicated tank
comparisons.

- [`aqt_align_events()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_align_events.md)
- [`aqt_design_audit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_design_audit.md)
- [`aqt_event_epoch_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_event_epoch_summary.md)
- [`aqt_event_table()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_event_table.md)
- [`aqt_tank_event_contrast()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tank_event_contrast.md)

### 7. Functional and longitudinal trajectories (11)

Functional curves, sparse and dense PCA and hierarchical longitudinal
models.

- [`aqt_functional_coverage()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_functional_coverage.md)
- [`aqt_functional_event_grid()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_functional_event_grid.md)
- [`aqt_functional_longitudinal_fit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_functional_longitudinal_fit.md)
- [`aqt_functional_longitudinal_prepare()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_functional_longitudinal_prepare.md)
- [`aqt_functional_tank_contrast()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_functional_tank_contrast.md)
- [`aqt_hierarchical_event_fit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hierarchical_event_fit.md)
- [`aqt_hierarchical_event_prepare()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hierarchical_event_prepare.md)
- [`aqt_sparse_fpca_design_audit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sparse_fpca_design_audit.md)
- [`aqt_sparse_fpca_fit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sparse_fpca_fit.md)
- [`aqt_sparse_fpca_input()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sparse_fpca_input.md)
- [`aqt_trajectory_grid_pca()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_trajectory_grid_pca.md)

### 8. Trajectory comparison and recurrence (3)

Dynamic time warping and recurrence-based trajectory characterization.

- [`aqt_trajectory_dtw()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_trajectory_dtw.md)
- [`aqt_trajectory_dtw_matrix()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_trajectory_dtw_matrix.md)
- [`aqt_trajectory_recurrence()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_trajectory_recurrence.md)

### 9. Behavioural state transitions and HMMs (10)

Descriptive changepoints and conditional Gaussian HMM decoding, training
and evaluation.

- [`aqt_changepoint_event_delay()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_changepoint_event_delay.md)
- [`aqt_hmm_decode()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hmm_decode.md)
- [`aqt_hmm_event_tank_epochs()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hmm_event_tank_epochs.md)
- [`aqt_hmm_holdout_score()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hmm_holdout_score.md)
- [`aqt_hmm_recovery_audit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hmm_recovery_audit.md)
- [`aqt_hmm_simulate_truth()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hmm_simulate_truth.md)
- [`aqt_hmm_state_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hmm_state_summary.md)
- [`aqt_hmm_tank_event_contrast()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hmm_tank_event_contrast.md)
- [`aqt_hmm_transition_fit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hmm_transition_fit.md)
- [`aqt_state_changepoint()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_state_changepoint.md)

### 10. Measurement and identity uncertainty (20)

Explicit conditional perturbations of pixels, paths, optical parameters,
identities and outcomes.

- [`aqt_detection_dropout_scenarios()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_dropout_scenarios.md)
- [`aqt_detection_event_sensitivity()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_event_sensitivity.md)
- [`aqt_ensemble_event_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_ensemble_event_summary.md)
- [`aqt_ensemble_path_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_ensemble_path_summary.md)
- [`aqt_ensemble_summarize()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_ensemble_summarize.md)
- [`aqt_ensemble_tracks()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_ensemble_tracks.md)
- [`aqt_identity_draw()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_identity_draw.md)
- [`aqt_identity_event_sensitivity()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_identity_event_sensitivity.md)
- [`aqt_identity_path_sensitivity()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_identity_path_sensitivity.md)
- [`aqt_identity_switch_scenarios()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_identity_switch_scenarios.md)
- [`aqt_identity_tank_sensitivity()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_identity_tank_sensitivity.md)
- [`aqt_joint_event_sensitivity()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_joint_event_sensitivity.md)
- [`aqt_joint_refractive_scenarios()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_joint_refractive_scenarios.md)
- [`aqt_joint_scene_cloud()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_joint_scene_cloud.md)
- [`aqt_joint_tank_sensitivity()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_joint_tank_sensitivity.md)
- [`aqt_reconstruction_pixel_uncertainty()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_reconstruction_pixel_uncertainty.md)
- [`aqt_stereo_pixel_mc()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_stereo_pixel_mc.md)
- [`aqt_tracking_position_error_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tracking_position_error_summary.md)
- [`aqt_tracking_position_errors()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tracking_position_errors.md)
- [`aqt_trajectory_ensemble()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_trajectory_ensemble.md)

### 11. Physical 3D target benchmarking (4)

Heldout physical XYZ targets, benchmark diagnostics and depth accuracy.

- [`aqt_stereo_depth_audit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_stereo_depth_audit.md)
- [`aqt_stereo_landmark_benchmark()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_stereo_landmark_benchmark.md)
- [`aqt_target_holdout_benchmark()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_target_holdout_benchmark.md)
- [`aqt_target_trial_table()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_target_trial_table.md)

### 12. Animal–Computer Interaction (6)

Recorded ACI choice, fairness, latency and feedback-loop telemetry.

- [`aqt_aci_access_inequality()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_aci_access_inequality.md)
- [`aqt_aci_choice_log()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_aci_choice_log.md)
- [`aqt_aci_choice_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_aci_choice_summary.md)
- [`aqt_aci_latency_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_aci_latency_summary.md)
- [`aqt_aci_loop_metrics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_aci_loop_metrics.md)
- [`aqt_aci_trials()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_aci_trials.md)

### 13. Visualizations and publication figures (22)

Static publication plots, trajectory storyboards and optional 3D views.

- [`aqt_plot_calibration_comparison()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_calibration_comparison.md)
- [`aqt_plot_changepoints()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_changepoints.md)
- [`aqt_plot_ensemble2d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_ensemble2d.md)
- [`aqt_plot_ensemble3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_ensemble3d.md)
- [`aqt_plot_feeding_states()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_feeding_states.md)
- [`aqt_plot_grid_pca()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_grid_pca.md)
- [`aqt_plot_heading_rose()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_heading_rose.md)
- [`aqt_plot_joint_scene_cloud()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_joint_scene_cloud.md)
- [`aqt_plot_joint_scene_cloud3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_joint_scene_cloud3d.md)
- [`aqt_plot_occupancy_timeseries()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_occupancy_timeseries.md)
- [`aqt_plot_path3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_path3d.md)
- [`aqt_plot_paths()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_paths.md)
- [`aqt_plot_reconstruction_qc()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_reconstruction_qc.md)
- [`aqt_plot_recurrence()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_recurrence.md)
- [`aqt_plot_school3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_school3d.md)
- [`aqt_plot_school_dynamics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_school_dynamics.md)
- [`aqt_plot_speed_response()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_speed_response.md)
- [`aqt_plot_tank_changes()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_tank_changes.md)
- [`aqt_plot_tank_projection()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_tank_projection.md)
- [`aqt_plot_tank_scene3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_tank_scene3d.md)
- [`aqt_plot_trajectory_storyboard3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_trajectory_storyboard3d.md)
- [`aqt_plot_voxel3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_voxel3d.md)

### 14. Provenance and source traceability (2)

Source data digest recording and verification.

- [`aqt_provenance_new()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_provenance_new.md)
- [`aqt_provenance_verify()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_provenance_verify.md)

------------------------------------------------------------------------

**Note:** This index establishes software discoverability, not
biological validity. When using functions for experimental conclusions,
review the associated topic’s measurement assumptions, source data,
independent validation requirements and experimental unit.
