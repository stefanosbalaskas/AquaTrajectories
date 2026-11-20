# Package index

## Data models, import and export

Canonical track objects, synthetic examples and interoperable data
formats.

- [`aqt_export_csv()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_export_csv.md)
  : Export canonical trajectories
- [`aqt_frame_index_analyze()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_frame_index_analyze.md)
  : Frame-indexed aquatic movement and group-geometry analysis
- [`aqt_frame_index_publish()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_frame_index_publish.md)
  : Publish a frame-indexed observation-quality and movement report
- [`aqt_frame_manifest()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_frame_manifest.md)
  : Validate an independently exported video frame timing manifest
- [`aqt_import_csv()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_import_csv.md)
  : Import a canonical long-format CSV
- [`aqt_import_idtracker()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_import_idtracker.md)
  : Import long-form idtracker.ai tracks after explicit reshaping
- [`aqt_import_mot()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_import_mot.md)
  : Import MOTChallenge/ByteTrack 2D detections using measured video PTS
- [`aqt_import_yolo()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_import_yolo.md)
  : Import explicitly exported YOLO/Ultralytics long-format tracks
- [`aqt_mot_support_audit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_mot_support_audit.md)
  : Audit tracker support against actual video frame availability
- [`aqt_research_bundle_export()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_research_bundle_export.md)
  : Export an unchanged, verified research bundle without losing
  provenance
- [`aqt_research_bundle_import()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_research_bundle_import.md)
  : Import a versioned Python-to-R aquatic tracking research bundle
- [`aqt_research_analyze()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_research_analyze.md)
  : Run a unified, QC-linked aquatic scientific research analysis
- [`aqt_research_export()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_research_export.md)
  : Export a complete, auditable scientific-analysis result without
  recomputation
- [`aqt_research_figure_plan()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_research_figure_plan.md)
  : Plan source-supported scientific publication figures
- [`aqt_research_publish()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_research_publish.md)
  : Export actual scientific figures and a provenance-linked publication
  report
- [`aqt_simulate_tracks()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_simulate_tracks.md)
  : Simulate deterministic mathematical fish paths
- [`aqt_tracks()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tracks.md)
  : Construct a validated aquatic-animal trajectory table
- [`aqt_tracks_validate()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tracks_validate.md)
  : Validate trajectory structure
- [`aqt_video_bundle_import()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_video_bundle_import.md)
  : Read a complete, SHA-256-checked Python video tracking export bundle

## Detection, tracking and annotation validation

Detector and identity metrics against explicitly defined reference
annotations.

- [`aqt_3dzef_agreement_import()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_3dzef_agreement_import.md)
  : Import a SHA-256-verified 3D-ZeF published-label agreement report
- [`aqt_annotation_frame_plan()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_annotation_frame_plan.md)
  : Prespecify a random time-stratified video annotation frame sample
- [`aqt_annotation_plan_audit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_annotation_plan_audit.md)
  : Audit prespecified video-frame annotation sample support and
  coverage
- [`aqt_apply_identity_corrections()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_apply_identity_corrections.md)
  : Apply explicitly reviewed individual identity corrections
- [`aqt_box_iou()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_box_iou.md)
  : Calculate pairwise intersection over union of axis-aligned
  rectangles
- [`aqt_detection_ap()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_ap.md)
  : Detection average precision using confidence-ranked 101-point
  interpolation
- [`aqt_detection_boxes()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_boxes.md)
  : Validate labelled detector bounding boxes
- [`aqt_detection_map()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_map.md)
  : Summarize mean average precision across fish classes and IoU
  thresholds
- [`aqt_detection_match()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_match.md)
  : Match fish detections to independent ground-truth boxes
- [`aqt_detection_metrics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_metrics.md)
  : Detection precision, recall, F1 and one-to-one match counts
- [`aqt_evaluation_frames()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_evaluation_frames.md)
  : Declare the video frames covered by manual ground-truth annotation
- [`aqt_track_qc()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_track_qc.md)
  : Track QC flags for missing positions, time gaps, and implausible
  motion
- [`aqt_trajectory_qc()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_trajectory_qc.md)
  : Audit video-derived aquatic trajectories without editing source
  observations
- [`aqt_qc_review()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_qc_review.md)
  : Apply documented review decisions without changing the original
  trajectories
- [`aqt_qc_derive()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_qc_derive.md)
  : Calculate audited movement only from reviewed, eligible observations
- [`aqt_qc_report()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_qc_report.md)
  : Export a complete, immutable, provenance-linked trajectory QC audit
- [`aqt_tracking_match()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tracking_match.md)
  : Match separately observed fish positions to reference tracks
- [`aqt_tracking_metrics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tracking_metrics.md)
  : Tracking identity F1 and within-camera association diagnostics
- [`aqt_tracking_observations()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tracking_observations.md)
  : Validate manually labelled or predicted point tracks for
  benchmarking
- [`aqt_video_bundle_benchmark()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_video_bundle_benchmark.md)
  : Score a verified single-camera bundle on independently annotated
  frames

## Camera calibration, optics and synchronization

Projection rigs, camera-clock diagnostics, Brown distortion and
refractive optics.

- [`aqt_brown_camera()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_brown_camera.md)
  : Define measured Brown-Conrady perspective lens distortion
  coefficients
- [`aqt_brown_distort_pixels()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_brown_distort_pixels.md)
  : Apply a known Brown radial/tangential lens distortion model
- [`aqt_brown_undistort_pixels()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_brown_undistort_pixels.md)
  : Invert a known Brown perspective lens distortion with residual QC
- [`aqt_brown_undistort_tracks()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_brown_undistort_tracks.md)
  : Preserve tracker provenance while undistorting canonical fish video
  tracks
- [`aqt_flatport_camera()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_flatport_camera.md)
  : Parameterize two parallel air-glass-water optical interfaces
- [`aqt_flatport_rays()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_flatport_rays.md)
  : Trace source pixels through both surfaces of a flat aquarium glass
  wall
- [`aqt_flatport_rays_distorted()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_flatport_rays_distorted.md)
  : Trace distorted camera pixels through a measured flat-port glass
  model
- [`aqt_flatport_refine_center()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_flatport_refine_center.md)
  : Refine flat-port camera translation using measured 3D landmarks
- [`aqt_refractive_camera()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_camera.md)
  : Define one calibrated ideal air-water planar refractive camera
- [`aqt_refractive_landmark_qc()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_landmark_qc.md)
  : Compare manually verified underwater landmark positions with traced
  rays
- [`aqt_refractive_rays()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_rays.md)
  : Trace image pixels through a single ideal planar refractive
  interface
- [`aqt_rig_baseline()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_rig_baseline.md)
  : Calculate camera-centre separation under a pinhole model
- [`aqt_rig_new()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_rig_new.md)
  : Construct a calibrated pinhole camera rig
- [`aqt_rig_project()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_rig_project.md)
  : Project known world XYZ positions into one camera's image plane
- [`aqt_rig_validate()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_rig_validate.md)
  : Verify calibrated camera rig structure
- [`aqt_scale_calibrate()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_scale_calibrate.md)
  : Convert 2D image coordinates using an externally measured constant
  scale
- [`aqt_sync_apply()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sync_apply.md)
  : Apply the camera clock transform
- [`aqt_sync_fit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sync_fit.md)
  : Estimate camera offset and drift from shared sync events
- [`aqt_sync_holdout_apply()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sync_holdout_apply.md)
  : Apply per-session validated clock fits without discarding raw
  timestamps
- [`aqt_sync_holdout_fit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sync_holdout_fit.md)
  : Fit camera clock offsets and drifts with independent sync-marker
  holdouts

## 3D reconstruction and cross-camera association

Geometric fish association, abstentions, triangulation and
reconstruction quality.

- [`aqt_auto_refractive_pipeline()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_auto_refractive_pipeline.md)
  : Automatic two-camera fish association and refractive 3D
  reconstruction
- [`aqt_candidate_rank()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_candidate_rank.md)
  : Rank cross-view geometry candidates and flag ambiguous matches
- [`aqt_correspondences_from_review()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_correspondences_from_review.md)
  : Turn documented human-reviewed candidate selections into
  correspondences
- [`aqt_crossview_auto_associate()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_crossview_auto_associate.md)
  : Select stable provisional fish identities across camera views
- [`aqt_multiview_global_fuse()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_multiview_global_fuse.md)
  : Fuse globally consistent provisional identities from three or more
  cameras
- [`aqt_multiview_holdout_protocol()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_multiview_holdout_protocol.md)
  : Combine disjoint camera-clock and surveyed underwater target holdout
  audits
- [`aqt_reconstruct_3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_reconstruct_3d.md)
  : Reconstruct explicitly matched two-view fish trajectories into 3D
- [`aqt_reconstruction_quality()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_reconstruction_quality.md)
  : Summarize quality of reconstructed stereo fish positions
- [`aqt_refractive_reconstruct_tracks()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_reconstruct_tracks.md)
  : Reconstruct manually matched two-view fish tracks through refractive
  rays
- [`aqt_refractive_track_quality()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_track_quality.md)
  : Audit physical ray residuals and clock skew in refractive 3D fish
  tracks
- [`aqt_refractive_triangulate()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_triangulate.md)
  : Triangulate externally paired fish observations as underwater rays
- [`aqt_refractive_view_candidates()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_view_candidates.md)
  : Generate unreviewed cross-camera refractive fish match candidates
- [`aqt_triangulate_pairs()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_triangulate_pairs.md)
  : Reconstruct 3D from already-matched calibrated pinhole observations
- [`aqt_view_candidates()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_view_candidates.md)
  : Generate geometric cross-view match candidates without assigning
  fish IDs

## Movement, schooling and space

Kinematics, 2D/3D school geometry, occupancy and observed scene
snapshots.

- [`aqt_group_metrics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_group_metrics.md)
  : Group cohesion and 2D/3D directional polarization
- [`aqt_group_pairwise_distances()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_group_pairwise_distances.md)
  : All simultaneous observed inter-fish distances within a
  camera/session
- [`aqt_group_spatial_edges()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_group_spatial_edges.md)
  : Thresholded fish-school spatial association edge list
- [`aqt_group_spatial_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_group_spatial_summary.md)
  : Simultaneous fish-school centroid, radius and spatial extent
- [`aqt_kinematics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_kinematics.md)
  : Timestamp-aware 2D/3D swimming kinematics
- [`aqt_path_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_path_summary.md)
  : Per-individual path summaries
- [`aqt_tank_scene_snapshot()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tank_scene_snapshot.md)
  : Snapshot verified XYZ fish positions and unbridged recent movement
- [`aqt_tank_scene_storyboard()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tank_scene_storyboard.md)
  : Assemble bounded time-ordered 3D tank storyboard frames
- [`aqt_voxel_entropy()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_voxel_entropy.md)
  : Shannon occupancy entropy for a 3D voxelized fish tank
- [`aqt_voxel_occupancy()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_voxel_occupancy.md)
  : Estimate 3D spatial occupancy on an explicitly defined voxel grid
- [`aqt_zone_occupancy()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_zone_occupancy.md)
  : Summarize sampled spatial occupancy within user-defined rectangles

## Events, tank replication and inference

Experimental-event alignment and independently replicated tank
comparisons.

- [`aqt_align_events()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_align_events.md)
  : Align trajectories or features with experimental events
- [`aqt_design_audit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_design_audit.md)
  : Audit between-tank treatment replication and experimental-unit
  independence
- [`aqt_event_epoch_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_event_epoch_summary.md)
  : Summarize fish behaviour in named windows around recorded events
- [`aqt_event_table()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_event_table.md)
  : Validate a timestamped event table
- [`aqt_tank_event_contrast()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tank_event_contrast.md)
  : Estimate a tank-replicated difference in event-related changes

## Functional and longitudinal trajectories

Functional curves, sparse and dense PCA and hierarchical longitudinal
models.

- [`aqt_functional_coverage()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_functional_coverage.md)
  : Audit the observed support of time-aligned fish functions
- [`aqt_functional_event_grid()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_functional_event_grid.md)
  : Align observed fish behaviour to event-relative functional time
- [`aqt_functional_longitudinal_fit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_functional_longitudinal_fit.md)
  : Fit a tank/fish nested event-relative spline with optional AR(1)
  errors
- [`aqt_functional_longitudinal_prepare()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_functional_longitudinal_prepare.md)
  : Validate fully supported event-relative fish curves for mixed models
- [`aqt_functional_tank_contrast()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_functional_tank_contrast.md)
  : Fit a tank-replicated functional treatment contrast with cluster
  bands
- [`aqt_hierarchical_event_fit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hierarchical_event_fit.md)
  : Fit a tank/fish nested longitudinal model using established nlme
- [`aqt_hierarchical_event_prepare()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hierarchical_event_prepare.md)
  : Prepare fish-within-tank event measurements for hierarchical
  analysis
- [`aqt_sparse_fpca_design_audit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sparse_fpca_design_audit.md)
  : Audit sparse functional observation coverage in common time bins
- [`aqt_sparse_fpca_fit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sparse_fpca_fit.md)
  : Fit an independently maintained sparse FPCA backend to fish
  coordinates
- [`aqt_sparse_fpca_input()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sparse_fpca_input.md)
  : Convert incomplete aquatic trajectories to sparse functional
  observations
- [`aqt_trajectory_grid_pca()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_trajectory_grid_pca.md)
  : Dense-grid approximation to multivariate functional trajectory PCA

## Trajectory comparison and recurrence

Dynamic time warping and recurrence-based trajectory characterization.

- [`aqt_trajectory_dtw()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_trajectory_dtw.md)
  : Multivariate dynamic time warping for validated 2D/3D fish paths
- [`aqt_trajectory_dtw_matrix()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_trajectory_dtw_matrix.md)
  : Pairwise DTW distance matrix across independently scoped fish tracks
- [`aqt_trajectory_recurrence()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_trajectory_recurrence.md)
  : Recurrence quantification for a complete 2D or 3D fish path

## Behavioural state transitions and HMMs

Descriptive changepoints and conditional Gaussian HMM decoding, training
and evaluation.

- [`aqt_changepoint_event_delay()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_changepoint_event_delay.md)
  : Describe delay from a logged event to the next observed change point
- [`aqt_hmm_decode()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hmm_decode.md)
  : Decode bounded fish behavioural states under an explicit Gaussian
  HMM
- [`aqt_hmm_event_tank_epochs()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hmm_event_tank_epochs.md)
  : Aggregate event-aligned posterior fish states to independent tanks
- [`aqt_hmm_holdout_score()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hmm_holdout_score.md)
  : Score held-out fish under a fixed trained HMM without leakage
- [`aqt_hmm_recovery_audit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hmm_recovery_audit.md)
  : Audit Gaussian HMM transition and state recovery on unseen synthetic
  tanks
- [`aqt_hmm_simulate_truth()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hmm_simulate_truth.md)
  : Simulate labelled fish trajectories from a known Gaussian-state HMM
- [`aqt_hmm_state_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hmm_state_summary.md)
  : Summarize decoded fish states without pseudoreplication
- [`aqt_hmm_tank_event_contrast()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hmm_tank_event_contrast.md)
  : Compare two-arm fish HMM event changes with tank-level resampling
- [`aqt_hmm_transition_fit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_hmm_transition_fit.md)
  : Estimate HMM transition dynamics while holding Gaussian emissions
  fixed
- [`aqt_state_changepoint()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_state_changepoint.md)
  : Detect penalized mean changes in one complete fish behaviour series

## Measurement and identity uncertainty

Explicit conditional perturbations of pixels, paths, optical parameters,
identities and outcomes.

- [`aqt_detection_dropout_scenarios()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_dropout_scenarios.md)
  : Simulate temporally correlated fish-detection misses as conditional
  sensitivity scenarios
- [`aqt_detection_event_sensitivity()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_event_sensitivity.md)
  : Recompute behavioural event epochs across detection-loss scenarios
- [`aqt_ensemble_event_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_ensemble_event_summary.md)
  : Propagate spatial noise scenarios into event-aligned fish behaviour
- [`aqt_ensemble_path_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_ensemble_path_summary.md)
  : Propagate spatial measurement scenarios into fish path statistics
- [`aqt_ensemble_summarize()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_ensemble_summarize.md)
  : Summarize across conditional trajectory measurement-error scenarios
- [`aqt_ensemble_tracks()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_ensemble_tracks.md)
  : Extract one complete trajectory scenario without altering the
  reference
- [`aqt_identity_draw()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_identity_draw.md)
  : Materialize one internally coherent identity-assignment scenario
- [`aqt_identity_event_sensitivity()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_identity_event_sensitivity.md)
  : Propagate discrete identity assignments to event-aligned fish
  measures
- [`aqt_identity_path_sensitivity()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_identity_path_sensitivity.md)
  : Propagate alternate fish identities into coherent swimming paths
- [`aqt_identity_switch_scenarios()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_identity_switch_scenarios.md)
  : Define explicit candidate identity switches and draw coherent
  assignments
- [`aqt_identity_tank_sensitivity()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_identity_tank_sensitivity.md)
  : Propagate identity uncertainty into independently replicated tank
  contrasts
- [`aqt_joint_event_sensitivity()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_joint_event_sensitivity.md)
  : Recalculate event-aligned fish behaviour for every joint optical/ID
  draw
- [`aqt_joint_refractive_scenarios()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_joint_refractive_scenarios.md)
  : Simulate coherent glass-camera and discrete fish-ID uncertainty
  scenarios
- [`aqt_joint_scene_cloud()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_joint_scene_cloud.md)
  : Extract time-locked physical fish positions under all joint
  scenarios
- [`aqt_joint_tank_sensitivity()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_joint_tank_sensitivity.md)
  : Compare tank-level event contrasts under joint optical/identity
  scenarios
- [`aqt_reconstruction_pixel_uncertainty()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_reconstruction_pixel_uncertainty.md)
  : Attach pixel-noise stereo uncertainty to a reconstructed 3D fish
  path
- [`aqt_stereo_pixel_mc()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_stereo_pixel_mc.md)
  : Propagate assumed camera pixel localization noise into stereo XYZ
- [`aqt_tracking_position_error_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tracking_position_error_summary.md)
  : Summarize empirical localization residuals by camera and session
- [`aqt_tracking_position_errors()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tracking_position_errors.md)
  : Extract matched position errors from independent annotated fish
  tracks
- [`aqt_trajectory_ensemble()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_trajectory_ensemble.md)
  : Construct coherent measurement-error scenarios for 2D/3D fish
  trajectories

## Physical 3D target benchmarking

Heldout physical XYZ targets, benchmark diagnostics and depth accuracy.

- [`aqt_stereo_depth_audit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_stereo_depth_audit.md)
  : Summarize 3D reconstruction accuracy across prespecified tank depths
- [`aqt_stereo_landmark_benchmark()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_stereo_landmark_benchmark.md)
  : Evaluate refractive stereo coordinates against independent physical
  truth
- [`aqt_target_holdout_benchmark()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_target_holdout_benchmark.md)
  : Benchmark underwater stereo models only on independent heldout
  targets
- [`aqt_target_trial_table()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_target_trial_table.md)
  : Validate an independently measured underwater stereo target
  experiment

## Animal–Computer Interaction

Recorded ACI choice, fairness, latency and feedback-loop telemetry.

- [`aqt_aci_access_inequality()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_aci_access_inequality.md)
  : Quantify observed inequality in use of offered device choices
- [`aqt_aci_choice_log()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_aci_choice_log.md)
  : Validate externally recorded animal choice opportunities and
  selections
- [`aqt_aci_choice_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_aci_choice_summary.md)
  : Separate offered fish choices from actually selected alternatives
- [`aqt_aci_latency_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_aci_latency_summary.md)
  : Summarize measured fish-device loop latency without timing
  imputation
- [`aqt_aci_loop_metrics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_aci_loop_metrics.md)
  : Summarize animal-action to physical-device contingency by trial
  group
- [`aqt_aci_trials()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_aci_trials.md)
  : Validate externally annotated fish-device interaction trials

## Visualizations and publication figures

Static publication plots, trajectory storyboards and optional 3D views.

- [`aqt_plot_calibration_comparison()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_calibration_comparison.md)
  : Compare three-dimensional reconstruction errors on held-out targets
- [`aqt_plot_changepoints()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_changepoints.md)
  : Plot observed fish behaviour and descriptive detected change points
- [`aqt_plot_ensemble2d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_ensemble2d.md)
  : Visualize conditional position-error trajectories alongside observed
  fish
- [`aqt_plot_ensemble3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_ensemble3d.md)
  : Plot conditional 3D fish trajectory ensembles using optional rgl
- [`aqt_plot_feeding_states()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_feeding_states.md)
  : Plot supplied feeding-behaviour phases against a measured index
- [`aqt_plot_grid_pca()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_grid_pca.md)
  : Plot the mean 2D/3D trajectory and one dense-grid PCA mode
- [`aqt_plot_heading_rose()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_heading_rose.md)
  : Plot swimming-heading rose diagrams with explicit angle conventions
- [`aqt_plot_joint_scene_cloud()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_joint_scene_cloud.md)
  : Plot a projected uncertainty scenario cloud without Gaussian
  assumptions
- [`aqt_plot_joint_scene_cloud3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_joint_scene_cloud3d.md)
  : Visualize real XYZ scenario points in optional rgl
- [`aqt_plot_occupancy_timeseries()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_occupancy_timeseries.md)
  : Plot tank-level spatial occupancy trajectories and uncertainty bands
- [`aqt_plot_path3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_path3d.md)
  : Plot true 3D trajectories with explicit missing/gap segmentation
- [`aqt_plot_paths()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_paths.md)
  : Plot 2D trajectories without joining unobserved or long-gap segments
- [`aqt_plot_reconstruction_qc()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_reconstruction_qc.md)
  : Inspect reconstructed 3D trajectory quality using two diagnostic
  plots
- [`aqt_plot_recurrence()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_recurrence.md)
  : Plot a trajectory recurrence matrix
- [`aqt_plot_school3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_school3d.md)
  : Show simultaneous observed fish-school positions in physical 3D
- [`aqt_plot_school_dynamics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_school_dynamics.md)
  : Plot observed school geometry over time without frame-level
  inference
- [`aqt_plot_speed_response()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_speed_response.md)
  : Plot swimming-speed changes around a known experimental intervention
- [`aqt_plot_tank_changes()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_tank_changes.md)
  : Visualize independent tank-level before/after changes
- [`aqt_plot_tank_projection()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_tank_projection.md)
  : Plot an orthographic XY/XZ/YZ projection of a measured 3D fish scene
- [`aqt_plot_tank_scene3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_tank_scene3d.md)
  : Display 3D fish scene with optional rgl graphics
- [`aqt_plot_trajectory_storyboard3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_trajectory_storyboard3d.md)
  : Publication-style four-panel 3D fish trajectory storyboard
- [`aqt_plot_voxel3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_voxel3d.md)
  : Plot 3D occupancy voxels as an observed-sample point cloud

## Provenance and source traceability

Source data digest recording and verification.

- [`aqt_provenance_new()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_provenance_new.md)
  : Create an immutable-input inventory for a fish-tracking analysis
- [`aqt_provenance_verify()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_provenance_verify.md)
  : Recalculate file digests to check source integrity
