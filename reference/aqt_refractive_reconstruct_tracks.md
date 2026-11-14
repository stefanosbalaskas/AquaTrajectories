# Reconstruct manually matched two-view fish tracks through refractive rays

Accepts previously reviewed, exact camera-local fish correspondences.
The 2D observations must share calibrated clock time and pixel system,
but their biological source track IDs may be different. The supplied
refractive camera models can be ideal one-interface or two-interface
flat glass ports. Does not automatically discover fish correspondences.

## Usage

``` r
aqt_refractive_reconstruct_tracks(
  view_a,
  view_b,
  correspondences,
  camera_a,
  camera_b,
  max_skew_s = 0.02,
  max_ray_separation = Inf
)
```

## Arguments

- view_a, view_b:

  Canonical single-camera 2D image/pixel tracks.

- correspondences:

  Data frame session_id, id_a, id_b, time_a_s,time_b_s,fish_id, with
  optional tank_id/treatment fields.

- camera_a, camera_b:

  Calibrated-parameter refractive camera models, with shared physical
  world coordinate units.

- max_skew_s:

  Maximum tolerated time difference after synchronization.

- max_ray_separation:

  Maximum accepted physical distance between closest underwater rays (cm
  or m, same as camera model).

## Value

3D aqt_tracks with source IDs, clock skew, 3D ray separation, original
reviewed assignments and explicit missing positions.
