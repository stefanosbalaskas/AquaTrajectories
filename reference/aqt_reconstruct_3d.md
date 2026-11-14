# Reconstruct explicitly matched two-view fish trajectories into 3D

This is a strict known-correspondence stereo primitive. The external
correspondences table must supply correctly matched fish identities and
original timestamps in two already synchronized camera clocks. A track
ID in one camera is NOT assumed to match the same ID in another.
Water/glass/air refraction and fisheye effects must be corrected with
separately validated calibration models; this function will reject a rig
declaring a refractive optical interface.

## Usage

``` r
aqt_reconstruct_3d(view_a, view_b, correspondences, rig, max_skew_s = 0.02)
```

## Arguments

- view_a, view_b:

  2D image-pixel aqt_tracks, each from one camera.

- correspondences:

  Data frame session_id, id_a, id_b, time_a_s, time_b_s, fish_id. Each
  row describes one known matching pair.

- rig:

  aqt_rig containing both cameras' P matrices.

- max_skew_s:

  Maximum permitted absolute synchronized time difference.

## Value

A physical-unit 3D aqt_tracks object with reprojection and time-skew
diagnostics and source track labels.
