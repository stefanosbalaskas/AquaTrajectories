# Wave 7C — independently surveyed underwater landmark benchmarking

## Problem addressed

A small closest-ray separation between two camera views is an INTERNAL
consistency metric. Even two wrongly calibrated cameras can intersect
their rays closely while estimating incorrect physical fish coordinates.

This wave adds external, actual-world XYZ validation against independently
surveyed physical calibration targets. A synthetic fixture is used to
test implementation mathematics; real 3D accuracy is NOT certified.

## Functions

- \`aqt_stereo_landmark_benchmark(camera_a,camera_b,pixels_a,pixels_b,
  landmarks_xyz)\`: compares paired, undistorted image observations
  with known metric-world 3D positions. Explicitly reports n_valid,
  invalid fraction, XYZ signed bias, per-axis RMSE, 3D RMSE/MAE/max and
  every landmark's residual. Invalid triangulations remain in the
  denominator and are never silently dropped from the accuracy report.
- \`aqt_stereo_depth_audit(benchmark,depth_breaks)\`: summarizes
  absolute XYZ error and valid-point fractions across researcher-defined
  TRUE physical depth intervals, not the depth inferred by the model.
- \`aqt_flatport_refine_center(camera,pixels,landmarks_xyz,training,holdout)\`:
  bounded nonlinear optimization of ONLY the 3D camera optical centre.
  Camera K, distortion status, orientation R, glass plane/normal/
  thickness and all refractive indices are fixed at supplied values.
  Training and independent holdout landmark IDs must be disjoint;
  repeated XYZ target positions across these partitions are rejected.
  Both before/after training and heldout perpendicular ray RMSE are
  explicitly returned, along with optimizer convergence.

## Example of measured physical targets

~~~r
library(aquaTrajectories)

# left, right: previously defined, measured-parameter cameras
# pa, pb: n-by-2 undistorted pixel matrices of corresponding targets
# physical: n-by-3 metric XYZ of independently surveyed targets
benchmark <- aqt_stereo_landmark_benchmark(
  left,right,pa,pb,physical,
  landmark_id=paste0("target_",seq_len(nrow(physical))),
  max_separation=.5
)
print(benchmark$summary)
print(aqt_stereo_depth_audit(benchmark,depth_breaks=c(0,10,20,30)))

# Fit centre translation with separately selected physical targets.
# Choose spatially diverse training and heldout targets in advance.
fit <- aqt_flatport_refine_center(
  left,pa,physical,
  training=1:12,holdout=13:16,
  max_center_shift=.25
)
print(fit$train_rmse_before)
print(fit$train_rmse_after)
print(fit$holdout_rmse_before)
print(fit$holdout_rmse_after)
print(fit$convergence)
~~~

This example presumes measured physical targets and known image
coordinates. No actual camera measurements are bundled here.

## Evaluation contract

- Physical truth must be independent of the fitted stereo reconstruction.
  Using triangulated coordinates as target truth invalidates calibration.
- The camera lens must be appropriately undistorted; this module does
  not optimize focal length, fish-eye distortion, glass normal, slab
  thickness, relative camera rotations, or clock synchronization.
- Camera centre refinement uses physical perpendicular ray residuals.
  A positive heldout improvement does not validate every possible
  depth, field of view, animal species or lighting condition.
- Training and holdout targets must be distinct physical locations.
  Repeated video frames from the SAME landmark are not independent
  validation targets, and must not leak across splits.
- The camera-centre fitted parameters remain uncertified. Source-image
  localization noise, surveying error, parameter covariance and 3D
  interval coverage remain open.
- Multiple depth, x/y location, angle and corner benchmarks must be
  conducted in the actual tank with its actual walls before claiming
  accurate fish trajectories.
- Report absolute 3D errors and invalid reconstruction fraction,
  not just 'successful reconstruction' or the distance between rays.

## Research milestones still needed

1. Model and estimate focal length, principal point, lens distortion,
   camera rotation, glass pose, thickness and refractive indices
   jointly, with identifiability checks.
2. Use blocked whole-landmark and whole-tank holdout sets to assess
   domain shift; do not split nearby video frames randomly.
3. Propagate empirical parameter covariance through 3D reconstruction,
   fish group metrics and tank-replicated treatment effects.
4. Independently cross-check existing underwater camera calibration
   frameworks and published benchmark datasets before declaring
   software metrological accuracy.
