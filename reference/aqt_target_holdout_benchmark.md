# Benchmark underwater stereo models only on independent heldout targets

Scores each externally supplied refractive camera pair against the
surveyed XYZ of holdout target assemblies; fit targets are NEVER used in
scoring. Per-trial denominators retain failed reconstructions. Results
do not prove the camera parameters were fitted without leakage: model
fitting, surveying quality and independent collection remain external
design responsibilities.

## Usage

``` r
aqt_target_holdout_benchmark(targets, cameras, max_ray_separation = Inf)
```

## Arguments

- targets:

  An aqt_target_trials data frame.

- cameras:

  Named list mapping camera IDs to compatible aqt_refraction_camera
  models, with common physical units.

- max_ray_separation:

  Maximum valid ray-ray residual, in model units.

## Value

aqt_target_holdout_audit, per-trial accuracy, per-target errors,
descriptive aggregate counts, without inflated target-level inference.
