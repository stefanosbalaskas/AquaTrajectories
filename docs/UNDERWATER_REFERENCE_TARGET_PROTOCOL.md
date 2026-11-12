# Wave 11C — physical GoPro underwater calibration and holdout targets

## Objective

The strongest remaining scientific claim—absolute underwater 3D fish
coordinates—cannot be established by ray-to-ray separation or a successful
R CMD check. It requires independently surveyed reference objects of
known XYZ positions, matched pixel measurements, and camera parameters
qualified on genuinely external target assemblies and acquisition runs.

This wave provides a strict machine-readable target protocol and scoring
functions. It does **not** create actual physical target measurements,
fit a complete GoPro/fisheye/flat-port calibration automatically, or
certify a real aquarium camera.

## Required physical acquisition design

1. Fix camera mounts, tank wall, interface normal, glass thickness,
   water level and camera settings; retain raw-video provenance. A
   strong digital stabilization, dynamic crop or wide fisheye mode may
   invalidate a fixed Brown perspective lens calibration.
2. Survey XYZ targets against a physical reference in the same cm/m
   world system as the camera models. Record instrument uncertainty,
   target thickness, surveyed measurement method and independent
   annotations. Do not treat drawing coordinates as physical truth.
3. Record physical calibration assemblies at several tank depths and
   across the field of view, including shallow, middle and deep
   locations and oblique angles.
4. Reserve whole **target groups / assemblies** for holdout rather
   than splitting corners of the same board between fitting and
   validation. Record different sessions/tanks as separate trials.
5. Use verified reference event markers for camera clock alignment;
   matching video filenames or nominal FPS does not establish
   synchronized camera exposure.
6. Supply camera-specific undistorted pixel positions matched to each
   physical target: R's bounded Brown correction is not a substitute
   for a verified fisheye/GoPro lens model where one is appropriate.

## CSV schema

`inst/extdata/underwater_target_protocol_template.csv` contains
**column names only**. No measurements or empirical RMSE are invented.

Required fields:

- `trial_id,tank_id,session_id`
- `camera_a_id,camera_b_id`
- `target_id,target_group,partition` (fit or holdout)
- `truth_x,truth_y,truth_z` (independently surveyed physical cm/m)
- `a_u_px,a_v_px,b_u_px,b_v_px` (undistorted paired image pixels)

Each trial must have one camera pair and tank/session, >=6 fit targets,
>=3 heldout targets, distinct target group labels across partitions
and physical depth variation in both partitions. Repeated XYZ or target
IDs inside a trial are not allowed.

## R analysis

~~~r
library(aquaTrajectories)
survey <- read.csv("real_underwater_target_measurements.csv")
targets <- aqt_target_trial_table(survey,units="cm")
# TOP and SIDE must be independently specified, dimensionally compatible
# aqt_refraction_camera objects based on actual physical setup.
audit <- aqt_target_holdout_benchmark(
  targets,cameras=list(TOP=camera_TOP,SIDE=camera_SIDE),
  max_ray_separation=.25)
print(audit$per_trial)
print(audit$summary)
write.csv(audit$per_target,"heldout_3d_target_errors.csv",row.names=FALSE)
~~~

The `fit` split is validated but intentionally **not used for
evaluation**. Camera-model fitting must happen independently upstream
using fit targets only; the function cannot verify that the physical
collection or fitting was actually independent. Translation-only
refinement exists in `aqt_flatport_refine_center()`, but is not a
complete lens/extrinsic/refraction calibration.

## Reporting and interpretation

Report 3D RMSE, signed axis bias, depth-specific errors, target
visibility/reconstruction validity, camera and target-group
configuration, physical reference accuracy and failure denominators.
The summary contains both trial-equal-mean RMSE and target-pooled
descriptive RMSE, and never equates pooled targets with independent
experimental tanks. Any all-invalid trial remains in the denominator,
with undefined RMSE explicitly NA.

Synthetic known truth validates code only. Actual underwater accuracy,
uncertainty interval coverage, cross-view fish identity, biological
behaviour classification and treatment effects remain unverified until
real recordings and independently measured references are analysed.
