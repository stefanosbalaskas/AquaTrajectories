# Automatic two-camera fish association and refractive 3D reconstruction

Integrated native 2D matching to refractive 3D trajectory pipeline.

## Usage

``` r
aqt_auto_refractive_pipeline(view_a, view_b, camera_a, camera_b,
  max_skew_s = 0.02, max_ray_separation = 0.5,
  min_support = 3L, ambiguity_margin = 0.05,
  max_candidates = 100000L)
```

## Arguments

- view_a, view_b:

  Two synchronized-camera pixel `aqt_tracks`, with externally checked
  timestamps.

- camera_a, camera_b:

  Compatible externally calibrated refractive models.

- max_skew_s:

  Timestamp tolerance in seconds.

- max_ray_separation:

  Maximum physically permitted ray-separation residual.

- min_support:

  Minimum temporal match count for a stable camera-pair identity.

- ambiguity_margin:

  Required separation from competing geometric pair errors.

- max_candidates:

  Maximum cross-camera geometric candidate count.

## Value

Object `aqt_auto_refractive_pipeline` containing candidate table,
cross-camera stable associations, `tracks_3d` or `NULL` if none,
diagnostics, and explicit physical/biological certification flags.

## Details

Requires actual camera-side 2D trajectories and separately calibrated
camera clocks and refractive parameters. It does not execute video
detection, prove hardware synchronization, or certify physical XYZ or
fish identity.
