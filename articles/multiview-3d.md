# Multiview fish trajectories and underwater refraction

## Multiview reconstruction and physical geometry

Adding a second camera can provide 3D information **only when the
physical mapping and correspondence problem is supported**. Two
uncalibrated fish videos do not magically provide measured depth.

![Two schematic cameras observing fish through an aquatic
interface.](../multiview.svg)

Conceptual illustration; the straight lines do not assert the measured
ray bending of any actual GoPro setup.

### Step 1 — Synchronize observation times

Camera timestamps can differ due to drift and offset.
[`aqt_sync_holdout_fit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sync_holdout_fit.md)
estimates a supported affine timing model against independently matched
events and holds out markers for checking.
[`aqt_sync_holdout_apply()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sync_holdout_apply.md)
preserves source time stamps and rejects unsupported extrapolation.

Fitted timestamp agreement is not automatically hardware exposure
synchronization.

### Step 2 — Declare and test the camera model

| Camera condition | Methods | Scientific warning |
|----|----|----|
| Idealized air-only projection | [`aqt_rig_new()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_rig_new.md), [`aqt_rig_project()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_rig_project.md) | Inappropriate for uncorrected underwater refraction |
| Single flat air/water interface | [`aqt_refractive_camera()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_camera.md), [`aqt_refractive_rays()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_rays.md) | One interface only |
| Parallel glass slab, air–glass–water | [`aqt_flatport_camera()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_flatport_camera.md), [`aqt_flatport_rays()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_flatport_rays.md) | Requires measured glass and optical parameters |
| Perspective radial/tangential distortion | [`aqt_brown_camera()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_brown_camera.md), [`aqt_brown_undistort_pixels()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_brown_undistort_pixels.md) | Not a universal fisheye correction |

The *actual physical* tank coordinate system, lens
intrinsics/extrinsics, medium indices, glass thickness and port
configuration must be supplied. No function independently certifies
their accuracy just because the code runs.

### Step 3 — Match fish between camera views

[`aqt_view_candidates()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_view_candidates.md)
and
[`aqt_candidate_rank()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_candidate_rank.md)
help examine possible paired observations.
[`aqt_refractive_view_candidates()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_view_candidates.md)
generates physically based candidate rays;
[`aqt_crossview_auto_associate()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_crossview_auto_associate.md)
produces **provisional, abstention-capable** track links.

[`aqt_auto_refractive_pipeline()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_auto_refractive_pipeline.md)
combines candidate association with supported refractive reconstruction.
The output is not guaranteed to be a permanent individual fish ID;
source IDs and abstentions must be reported.

### Step 4 — Reconstruct and audit XYZ

[`aqt_reconstruct_3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_reconstruct_3d.md)
handles externally known pinhole correspondences where appropriate;
[`aqt_refractive_reconstruct_tracks()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_reconstruct_tracks.md)
handles declared refractive geometry and reviewed pairs.
[`aqt_reconstruction_quality()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_reconstruction_quality.md)
and
[`aqt_refractive_track_quality()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_refractive_track_quality.md)
summarize supported diagnostic quantities.

### Step 5 — Validate against measured targets

Held-out measured target positions are the critical external anchor.
[`aqt_target_trial_table()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_target_trial_table.md),
[`aqt_target_holdout_benchmark()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_target_holdout_benchmark.md),
[`aqt_stereo_landmark_benchmark()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_stereo_landmark_benchmark.md)
and
[`aqt_stereo_depth_audit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_stereo_depth_audit.md)
support quality evaluation when true surveyed XYZ coordinates are
available.

A low reprojection error can coexist with a wrong fish identity or wrong
physical camera model.

#### Go deeper

[source
protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/docs/AUTOMATIC_CROSSVIEW_REFRACTIVE_PIPELINE.md)
· [source
protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/docs/FLATPORT_CAMERA_GEOMETRY.md)
· [source
protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/docs/UNDERWATER_REFERENCE_TARGET_PROTOCOL.md)
· [source
protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/docs/CAMERA_CLOCK_HOLDOUT.md).
