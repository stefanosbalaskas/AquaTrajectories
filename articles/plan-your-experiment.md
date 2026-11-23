# Plan your aquatic video experiment

## Plan an aquatic-animal video study

Start with your scientific question, not the number of cameras.
AquaTrajectories accepts 2D and 3D timestamped observations, but camera
geometry and independent reference data determine which claims can be
defended.

[One camera · 2D](#one-camera) [Two cameras · conditional
3D](#two-cameras) [I already have video](#existing-recordings)
[Pre-recording checklist](#before-recording)

### One camera

**Typical purpose:** planar locations, camera-local trajectories,
visible group geometry and carefully defined 2D zones. Record original
video, codec details, frame IDs and presentation timestamps. If
converting pixels to physical units, independently establish a suitable
spatial scale and confirm the assumptions of the measurement plane. A
single conventional camera does not recover unconstrained underwater
depth.

For detection accuracy, independently review fish bounding boxes **and
empty frames**; unresolved biological identities should stay unresolved.
Camera-local track numbers are not automatically stable biological fish
identities.

**Relevant methods:**
[`aqt_import_mot()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_import_mot.md),
[`aqt_import_yolo()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_import_yolo.md),
[`aqt_track_qc()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_track_qc.md),
[`aqt_kinematics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_kinematics.md),
[`aqt_group_metrics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_group_metrics.md).
See [video
tracking](https://stefanosbalaskas.github.io/AquaTrajectories/articles/video-tracking.md)
and [movement and
schooling](https://stefanosbalaskas.github.io/AquaTrajectories/articles/movement-and-schooling.md).

### Two cameras

**Typical purpose:** multiview observations that may support 3D
reconstruction after suitable calibration and association. Two GoPros
alone do **not** guarantee physical XYZ accuracy.

Record both source videos and original time bases. Plan independently
identified shared timing markers or external hardware exposure evidence;
estimate clock offset/drift against holdout markers. Document camera
intrinsics and pose, lens distortion, tank walls, refractive interfaces
and calibration settings. Establish cross-camera fish correspondence,
including abstention when ambiguous.

A physical XYZ-accuracy claim further requires **separately surveyed
underwater targets**, withheld from fitting and distributed over depths
and tank regions. Report invalid reconstructions as well as valid-point
error.

**Relevant methods:**
[`aqt_sync_holdout_fit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sync_holdout_fit.md),
[`aqt_refractive_triangulate()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_triangulate.md),
[`aqt_target_holdout_benchmark()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_target_holdout_benchmark.md).
Closest-ray distance and reprojection residuals are internal
consistency, not independently surveyed truth. See [multiview
3D](https://stefanosbalaskas.github.io/AquaTrajectories/articles/multiview-3d.md).

### Existing recordings

Preserve the originals and complete a preflight audit before generating
movement statistics:

1.  Register each recording/session/camera and source SHA-256 digest;
    retain original frame indices and presentation timestamps.
2.  Document the external detector checkpoint, thresholds,
    preprocessing, tracker and any overlap with evaluation video.
3.  Check annotation provenance, reviewed empty frames, gaps and unknown
    fish IDs.
4.  Locate actual calibration, exposure timing and independently
    measured physical targets; never substitute model output for those
    records.
5.  Restrict 3D, identity and welfare claims when those reference data
    are absent.

See [video to
results](https://stefanosbalaskas.github.io/AquaTrajectories/articles/video-to-results.md),
the [validation
matrix](https://stefanosbalaskas.github.io/AquaTrajectories/articles/capabilities-and-validation.md),
and [evidence
dashboard](https://stefanosbalaskas.github.io/AquaTrajectories/articles/research-evidence-dashboard.md).

### Before recording

Define the estimand (detection, individual movement, 3D XYZ, group
structure or intervention contrast).

Record fish species, density, tank dimensions, lighting, camera
placement and occlusion conditions.

Preserve original videos, frame manifests, timestamps, device settings,
hashes and detector/version identifiers.

Plan a prediction-blind annotation sample, including reviewed empty
frames and unresolved identities.

For multiple cameras, record independent sync markers, geometry and
withheld submerged XYZ reference targets.

For intervention studies, allocate and document **independent tanks**;
frames are repeated measurements, not treatment replicates.

Record event timings on a documented clock; retain ethics and permission
records.

The [experiment starter
kit](https://stefanosbalaskas.github.io/AquaTrajectories/articles/experiment-starter-kit.md)
provides synthetic examples, event logs and **blank** physical
reference-target templates. These are not real fish observations. The
[interactive teaching
lab](https://stefanosbalaskas.github.io/AquaTrajectories/synthetic-explorer.md)
demonstrates camera viewpoints and identity errors with invented data.

**Current pinned software:** [AquaTrajectories
v0.2.1](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.2.1)
· [Historical v0.1.1 Zenodo DOI
10.5281/zenodo.24262905](https://doi.org/10.5281/zenodo.24262905).
