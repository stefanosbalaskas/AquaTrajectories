# AquaTrajectories

Development-stage native R package for aquatic animal 2D/3D trajectories, movement metrics, event alignment, synchronization, and calibrated multiview geometry.

**Not an independently validated release.** Fish detector training, cross-camera identity matching, aquatic refraction correction, physiological stress detection, and coverage-calibrated statistical inference are not implemented.

## First-wave example

~~~r
library(aquaTrajectories)
x <- aqt_simulate_tracks(n_fish = 5, n_frames = 200)
kin <- aqt_kinematics(x, max_gap_s = 0.1)
school <- aqt_group_metrics(x, max_gap_s = 0.1)
aqt_plot_paths(x)
event <- aqt_event_table(data.frame(
  session_id = "S01", event_id = "routine_event", start_s = 3, end_s = 4
))
aligned <- aqt_align_events(kin, event)
~~~

The simulator produces purely synthetic random walks, not biologically calibrated fish behaviour.

## Core scientific guarantees

Camera- and session-scoped track IDs are not permanent animal identities. A 2D trajectory has unknown depth, not z = 0. Missing positions and long intervals are not silently interpolated. Pinhole stereo triangulation requires externally matched points and is inappropriate for uncorrected refraction. Camera-clock alignment is not physical exposure synchronization. Tank-level experimental replication and independent welfare validation remain necessary.

See docs/SCIENTIFIC_ROADMAP.md for planned advanced functionality and status.


## Wave 2: independently evaluated detectors and trackers

This development branch adds validation of independent fish detections
and individual identity assignments. The two accuracy problems are separate.

- Detection: aqt_detection_boxes(), aqt_box_iou(),
  aqt_detection_match(), aqt_detection_metrics(), aqt_detection_ap(),
  and aqt_detection_map(). Includes precision, recall, F1, IoU and
  confidence-ranked 101-point AP/mAP; NOT full COCO benchmark semantics.
- Identity tracking: aqt_tracking_observations(), aqt_tracking_match(),
  aqt_tracking_metrics(). Reports framewise matches, optimal global IDF1,
  adjacent ID switches and positional RMSE per session and camera.
  HOTA / official CLEAR MOT are NOT implemented.
- Ground-truth scope: aqt_evaluation_frames() makes sparse manual
  annotation explicit. Include manually reviewed empty frames.
- Provenance: aqt_provenance_new(), aqt_provenance_verify().
  File digests provide change detection, not authentication.
- Human corrections: aqt_apply_identity_corrections() maintains the
  original IDs and reviewer-provided correction log.

### Minimal validation demonstration

~~~r
truth <- data.frame(
  session_id="S1",camera_id="top",frame_id="0",class_id="fish",
  xmin=0,ymin=0,xmax=20,ymax=10
)
prediction <- transform(truth,confidence=.94)
aqt_detection_metrics(truth,prediction,confidence_threshold=.25)
aqt_detection_map(truth,prediction,iou_thresholds=c(.5,.75))

reference <- data.frame(session_id="S1",camera_id="top",
  frame_id=0:2,track_id="A",x=0:2,y=0)
estimate <- transform(reference,track_id=c("1","1","3"))
aqt_tracking_metrics(reference,estimate,max_distance=.1)
~~~

For assumptions, reference-label requirements, and scope limitations,
see docs/VALIDATION_CONTRACT.md.


## Wave 3A: calibrated known-correspondence stereo trajectories

Two (or more) named projection matrices define aqt_rig_new().
Use aqt_rig_project() and aqt_rig_baseline() for camera geometry.
aqt_reconstruct_3d() joins externally known cross-camera fish matches
at their actual, synchronized observation timestamps; 3D results carry
reprojection RMSE, camera timestamp differences and source fish IDs.
aqt_reconstruction_quality() summarizes those diagnostics.
aqt_voxel_occupancy() provides observed XYZ sample counts in predefined
physical-volume cells, and aqt_plot_reconstruction_qc() plots geometry/
clock diagnostics.

This stage is **strict known-correspondence pinhole stereo**, not automatic
cross-view matching, through-glass calibration, fisheye correction or
refraction-aware underwater tracking. It rejects rigs declaring a
refractive interface rather than silently producing invalid XYZ positions.

### Minimal synthetic stereo demonstration

~~~r
P1 <- cbind(diag(3),c(0,0,0))
P2 <- cbind(diag(3),c(-1,0,0))
rig <- aqt_rig_new(list(TOP=P1,SIDE=P2),units="cm",
                   optical_path="air_only")

top <- aqt_tracks(data.frame(session_id="S1",camera_id="TOP",
  track_id="top1",time_s=0,x=.5,y=.25))
side <- aqt_tracks(data.frame(session_id="S1",camera_id="SIDE",
  track_id="side1",time_s=0,x=.25,y=.25))
pairs <- data.frame(session_id="S1",id_a="top1",id_b="side1",
  time_a_s=0,time_b_s=0,fish_id="fishA")

xyz <- aqt_reconstruct_3d(top,side,pairs,rig)
print(xyz[,c("x","y","z","reprojection_rmse_px")])

occupancy <- aqt_voxel_occupancy(xyz,
  list(x=c(0,5),y=c(0,2),z=c(0,5)))
~~~

A low reprojection residual does not prove correct fish matching,
biological identity, or metric underwater accuracy.

## Wave 3B: geometry hypotheses and conditional 3D uncertainty

The native R package can now enumerate and rank plausible fish observation
pairs across two calibrated camera views WITHOUT automatically declaring a
permanent fish identity. Use aqt_view_candidates(), aqt_candidate_rank()
and aqt_correspondences_from_review() for an auditable review-to-reconstruction
pipeline. The raw source camera timestamps and identifiers remain traceable.

aqt_stereo_pixel_mc() and aqt_reconstruction_pixel_uncertainty() propagate
an explicitly assumed Gaussian image-localization error into 3D XYZ
sensitivity intervals. These are NOT validated confidence intervals, and
exclude identity switches, refraction, timing and camera calibration errors.

See docs/CROSSVIEW_UNCERTAINTY.md for the runnable example and full limits.



## Wave 4A: event windows and replicated tank-level analysis

- aqt_event_epoch_summary(): user-defined windows relative to actual event
  onset, with gap-safe sample or time-weighted behavioural means.
- aqt_design_audit(): count independent experimental tanks by treatment,
  and reject treatment switching under a simple between-tank design.
- aqt_tank_event_contrast(): differences in tank-level before/after
  responses between two treatment groups, resampling **tanks**, not
  individual fish or 30-fps video frames.
- aqt_plot_tank_changes(): paired per-tank before/after graphics.

These methods do not claim causal identification or small-sample
bootstrap interval calibration. See docs/EVENT_INFERENCE_CONTRACT.md.


## Wave 4B: coherent path-error scenarios and movement sensitivity

AquaTrajectories now evaluates how explicitly assumed measurement errors
can alter 2D/3D fish paths, swimming metrics and event-aligned outcomes.

- aqt_tracking_position_errors(), aqt_tracking_position_error_summary():
  inspect 2D coordinate residuals on independently annotated video frames.
- aqt_trajectory_ensemble(), aqt_ensemble_tracks(): draw reproducible
  paths with axis-specific noise, adjacent-sample correlation and
  systematic per-fish offsets.
- aqt_ensemble_path_summary(), aqt_ensemble_event_summary():
  recompute fish speeds, path lengths and event epochs in each scenario.
- aqt_ensemble_summarize(): empirical between-scenario sensitivity SD
  and interval, NOT a calibrated biological or experimental CI.
- aqt_plot_ensemble2d(), aqt_plot_ensemble3d(): visualize how
  hypothetical errors affect fish trajectories, with optional rgl.

This is a conditional, fixed-identity model. It excludes camera
calibration/refraction, timing errors, identity switches, unequal
reference coverage and independent-tank sampling uncertainty.
See docs/TRAJECTORY_UNCERTAINTY.md for examples and caveats.


## Installation and API documentation

The R package source now includes its generated \`NAMESPACE\` and \`man/\`
reference pages. Package documentation is regenerated from R source
roxygen comments during CI, and updated documentation is committed on
in-repository pull requests before the package check. Scientific validation
of the mathematical and biological contracts remains a separate requirement.


## Wave 5A: native fish trajectory comparison and functional-shape analysis

- aqt_trajectory_dtw(): Euclidean dynamic time warping for observed
  2D/3D fish positions, with a declared warping window.
- aqt_trajectory_dtw_matrix(): pairwise scoped fish trajectory distances.
- aqt_trajectory_recurrence(), aqt_plot_recurrence(): observed-position
  recurrence rate, diagonal-line determinism and laminarity with
  specified radius and Theiler exclusion.
- aqt_trajectory_grid_pca(), aqt_plot_grid_pca(): explicitly finite-grid
  multivariate XY/XYZ principal components registered to relative time,
  with mode curves and variance explained.

These methods reject missing/unobserved positions rather than inventing
data. Dense-grid PCA is not sparse/continuous FPCA and does not use an
unqualified EyeTrajectories backend. See docs/FUNCTIONAL_TRAJECTORY_METHODS.md.


## Wave 5B: school spatial geometry and interactive 3D

Fish-school spatial functions are now included in native R:
aqt_group_pairwise_distances(), aqt_group_spatial_summary(),
aqt_group_spatial_edges(), and aqt_voxel_entropy() quantify
simultaneous 2D/3D fish separation, school radius and spatial extent,
thresholded proximity edges, and conditional 3D occupancy entropy.

aqt_plot_school3d() visualizes an exact synchronized, calibrated 3D
school snapshot; aqt_plot_voxel3d() displays observed 3D voxel
occupancy; aqt_plot_school_dynamics() plots school geometry over time.
The 3D graphics use optional rgl; the core metrics need no Python.

Association edges do NOT prove leadership or animal preference.
Tracking dropouts, camera calibration and independent-tank replication
must still be handled independently. Details:
docs/SCHOOL_SPATIAL_METHODS.md.


## Wave 6A: explicitly parameterized refractive geometry

Native functions aqt_refractive_camera(), aqt_refractive_rays(),
aqt_refractive_triangulate() and aqt_refractive_landmark_qc()
implement and test Snell ray bending through ONE IDEAL planar interface,
plus independently measured 3D landmark residual checks.

**Not a complete flat-glass aquarium camera model.** Typical
air-glass-water optics involve TWO refractive surfaces; dome ports
and lens distortion are also not represented. User-supplied camera
parameters do not by themselves certify calibration. See
docs/REFRACTIVE_GEOMETRY.md.


## Wave 6B: discrete identity-switch scenarios through statistical conclusions

Five new functions model full-suffix ID exchanges within a camera/session
and propagate candidate identity assignments through speed, path length
and event-window summaries. For independently treated aquaculture tanks,
aqt_identity_tank_sensitivity() reports the distribution of separate
tank-level contrasts under each identity scenario and keeps
within-scenario tank bootstrap intervals separate.

**Caution:** externally specified identity-switch probabilities
are sensitivity assumptions, not automatically calibrated probabilities.
This module does not combine measurement and experimental sampling into
a validated joint confidence interval. Full assumptions are in
docs/IDENTITY_SCENARIOS.md.


## Wave 6C: sparse functional trajectories and hierarchical tanks

A new sparse-FDA preparation layer preserves only actual observed 2D/3D
coordinate values and timestamps. aqt_sparse_fpca_input() and
aqt_sparse_fpca_design_audit() report temporal support and missingness;
aqt_sparse_fpca_fit() optionally delegates strictly sparse estimation to
the established fdapace backend.

aqt_hierarchical_event_prepare() validates fish-within-tank repeated
measurements, while aqt_hierarchical_event_fit() uses optional nlme to
fit a simple tank/fish nested random-intercept treatment-by-epoch model.

No unqualified EyeTrajectories algorithm is called. A nested mixed model
does not automatically establish causal treatment effects. Detailed
contracts and examples: docs/SPARSE_HIERARCHICAL_METHODS.md.


## Wave 6D: two-interface air-glass-water optics

aqt_flatport_camera() and aqt_flatport_rays() model a physically
explicit flat, parallel glass slab between the source camera and
aquatic environment, tracing light through TWO optical interfaces
using Snell's law. Existing refractive triangulation and independent
3D landmark QC operate on these rays without automatically
identifying fish across views.

**Externally measured parameters are required**: lens intrinsics,
extrinsics, glass position and normal, thickness, refractive indices,
and physical tank coordinate units. This is not automatic calibration
nor a guarantee of metrological XYZ accuracy.
Details: docs/FLATPORT_CAMERA_GEOMETRY.md.


## Wave 7A: full fish trajectory reconstruction with flat-port optics

aqt_refractive_reconstruct_tracks() accepts explicitly reviewed,
camera-synchronized pixel-track correspondences and returns standard
3D fish trajectories under the supported one-interface or parallel
glass-slab refractive model. Source IDs, timestamps, clock skew,
physical ray residuals and observed/invalid flags remain available.

aqt_refractive_track_quality() summarizes session-level reconstruction
coverage, clock skew and ray-separation diagnostics. These outputs
feed the same 3D swimming, spatial, visual and event-statistical
functions as other properly calibrated XYZ tracks.

**No automatic fish re-identification or camera calibration is implied.**
See docs/REFRACTIVE_TRACK_RECONSTRUCTION.md for the contract.


## Wave 7B: conditional joint optics and fish identity uncertainty

Three new native R functions combine recording-level coherent perturbations
of refractive camera-centre and flat-glass parameters, pixel localization
noise, and explicit whole-segment fish-ID alternatives. They reconstruct
three-dimensional paths from reviewed camera observations and repeat
event-level outcomes and independently tank-replicated treatment contrasts
for every measurement scenario.

The outputs **do not constitute a statistically calibrated joint confidence
interval**. The separately resampled tanks represent a different
uncertainty source. See `docs/JOINT_REFRACTIVE_SENSITIVITY.md`.

## Wave 7C: independently measured 3D calibration landmarks

Physical 3D landmark comparison now has dedicated methods:
`aqt_stereo_landmark_benchmark()` reports absolute XYZ RMSE, bias and
failed reconstruction rates; `aqt_stereo_depth_audit()` examines
accuracy across true physical depth ranges; and
`aqt_flatport_refine_center()` offers strictly bounded
camera-centre-only optimization, with separately held-out known
landmarks and explicit before/after residuals.

These are external metrology tools, not automatic full-camera calibration.
The physical reference positions must actually be surveyed independently
in the tank. Full contracts: `docs/PHYSICAL_LANDMARK_BENCHMARKS.md`.

## Wave 8A: descriptive behavioural change points

`aqt_state_changepoint()` detects optimal piecewise-mean transitions in
one fully observed fish behaviour time series, with an explicit
complexity penalty and strict timestamp/missingness guards.
`aqt_changepoint_event_delay()` compares changes with logged event
onsets, while `aqt_plot_changepoints()` provides a basic diagnostic.

These are descriptive change points, **not** automatically classified
animal stress, welfare, HMM states or causal intervention responses.
See `docs/FISH_BEHAVIOURAL_CHANGEPOINTS.md`.


## Wave 8B: tank-replicated event-relative functional curves

`aqt_functional_event_grid()` aligns observed fish speed/XYZ outcomes
to actual event-relative recording seconds with strict missing-frame,
large-gap, and intervention-boundary interpolation guards.
`aqt_functional_coverage()` audits visible fish support over time.
`aqt_functional_tank_contrast()` estimates descriptive between-treatment
curves from independently replicated tank averages, with separate
pointwise and empirical simultaneous tank-resampling bands.

The resampling bands are NOT empirically coverage-certified confidence
intervals and DO NOT propagate glass-camera and fish identity errors.
See `docs/FUNCTIONAL_EVENT_TANK_CURVES.md`.

## Wave 9A: measured 3D tank storyboard and event overlays

`aqt_tank_scene_snapshot()` selects truly observed fish positions at
a specific recording time, retaining original IDs and never reusing
stale positions after an occlusion. Historical fish tails break at
missing frames and long gaps. `aqt_tank_scene_storyboard()` prepares
bounded sets of time-ordered verified scenes, while
`aqt_plot_tank_projection()` and optional
`aqt_plot_tank_scene3d()` visualize physical XY/XZ/YZ and XYZ.

This is not automatic 3D calibration, video playback or an inferred
welfare state. See `docs/THREED_TANK_STORYBOARD.md`.


## Wave 10A: animal–computer closed-loop telemetry and choice opportunities

`aqt_aci_trials()`, `aqt_aci_loop_metrics()` and
`aqt_aci_latency_summary()` audit externally recorded fish action,
detection, command, physical actuator and response times, separating
true and false triggers and incomplete loops. `aqt_aci_choice_log()`,
`aqt_aci_choice_summary()` and `aqt_aci_access_inequality()` separately
audit the actual options available to fish, the exercised selections,
and unequal access normalized by genuine multi-option opportunities.

These are descriptive fish–device measures, **not** validated agency,
preference, dominance or welfare scores; timing and biological
annotations require independent evidence. See
`docs/ACI_CLOSED_LOOP_TELEMETRY.md` and
`docs/ACI_CHOICE_AND_ACCESS.md`.


## Wave 8C: correlated longitudinal fish behaviour from independent tanks

`aqt_functional_longitudinal_prepare()` validates equally spaced,
fully observed fish event curves with between-tank treatments and
independent tanks; `aqt_functional_longitudinal_fit()` uses an
optional `nlme` Gaussian treatment-by-natural-spline model with
nested tank/fish random intercepts and optional within-fish AR(1)
residual structure. It is a bounded model, not a missing-data
solution, fish welfare classifier, causal estimator or qualified
EyeTrajectories native R port. Details:
`docs/FUNCTIONAL_LONGITUDINAL_NLME.md`.

## Wave 9B: multimodal 3D fish position uncertainty clouds

`aqt_joint_scene_cloud()` extracts all observed physical XYZ positions
from coherent joint optical/identity scenarios at a declared recording
frame and reports how many scenarios show each fish label.
`aqt_plot_joint_scene_cloud()` and optional
`aqt_plot_joint_scene_cloud3d()` display the full label-specific cloud
in physical XY/XZ/YZ and XYZ without imposing a Gaussian ellipsoid.

These are descriptive conditional sensitivity visualizations,
**not** scientifically calibrated 3D confidence regions or proof
of biological fish identity. Details:
`docs/JOINT_UNCERTAINTY_SCENE_CLOUD.md`.

## Wave 7D: independent camera clock synchronization holdouts

`aqt_sync_holdout_fit()` estimates camera-to-reference time offset and
drift separately for each recording session from externally matched
synchronization pulses. It requires >=4 training markers and >=2
disjoint physical heldout pulse IDs, reporting holdout RMSE and maximal
clock skew against a predeclared tolerance.
`aqt_sync_holdout_apply()` preserves original camera timestamps,
rejects failed heldout mappings by default, and refuses unapproved
time extrapolation. This adds physical timing diagnostics to underwater
reconstruction, **not** automatic hardware or biological synchronization
certification. See `docs/CAMERA_CLOCK_HOLDOUT.md`.

## Wave 7E: perspective-lens correction before underwater 3D fish tracking

`aqt_brown_camera()` declares an externally measured Brown–Conrady
perspective lens with radial and tangential distortion; the related
`aqt_brown_distort_pixels()` and `aqt_brown_undistort_pixels()`
perform forward and inversion maps with explicit convergence and
roundtrip pixel-error diagnostics. `aqt_brown_undistort_tracks()`
retains original detector pixels and missing fish observations, ready
for existing reviewed 2D-to-3D refractive reconstruction.
`aqt_flatport_rays_distorted()` composes this correction with
parallel two-interface air–glass–water rays.

**Not a universal GoPro fisheye lens model or automatic camera calibration.**
Perspective lens suitability and parameters must be independently
verified. See `docs/BROWN_LENS_FLATPORT.md`.

## Wave 8D: gap-safe conditional Gaussian fish-state decoding

`aqt_hmm_decode()` performs stable forward-backward posterior inference and
Viterbi decoding for 2..5 externally specified one-dimensional Gaussian
behavioural states (for example, speed). It requires explicitly supplied
state means, SDs and transition probabilities. `aqt_hmm_state_summary()`
reports fish-scoped sample fractions and state switches.

Tracking gaps, invalid observations, short unsupported segments and fish,
tank, camera or session boundaries are never bridged. No state parameters
are fitted from these observations; transitions describe consecutive
recorded samples, NOT continuous-time rates when sampling is irregular.
Frame-wise state frequencies are NOT independent tank replication,
physiological stress evidence, calibrated uncertainty or a causal effect.
Details: `docs/GAUSSIAN_HMM_BEHAVIOURAL_STATES.md`.

## Wave 8E: learned transition probabilities and independent-tank holdouts

`aqt_hmm_transition_fit()` fits Gaussian HMM initial and transition
probabilities using Baum-Welch expected state/transition counts over
gap-separated fish recordings. Means and SDs of each state remain
externally specified; the method does **not** estimate the full HMM
emission model. `aqt_hmm_holdout_score()` evaluates predictive log
likelihood on disjoint fish, requiring previously unseen experimental
tanks by default.

Training-frame scores, apparent convergence and even an independently
held-out likelihood are **not** validated welfare labels or
measurement-uncertainty-aware treatment estimates. Transitions represent
recorded observation steps, not continuous-time hazards.
See `docs/HMM_TRANSITION_HOLDOUT.md`.
