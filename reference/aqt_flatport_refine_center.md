# Refine flat-port camera translation using measured 3D landmarks

Optimizes ONLY the 3D camera optical centre, holding supplied camera
intrinsics, rotation, both parallel glass interfaces, thickness and
refractive indices fixed. Training and holdout landmarks must be
explicitly disjoint; independent holdout residuals remain visible. This
does not estimate full underwater calibration or uncertainty.

## Usage

``` r
aqt_flatport_refine_center(
  camera,
  pixels,
  landmarks_xyz,
  training,
  holdout,
  max_center_shift = 0.25,
  maxit = 500L
)
```

## Arguments

- camera:

  A physically parameterized aqt_flatport_camera.

- pixels:

  n-by-2 undistorted image coordinates of external targets.

- landmarks_xyz:

  n-by-3 independently surveyed world coordinates.

- training, holdout:

  Disjoint index vectors; \>=6 training, \>=2 holdout landmarks. Do not
  repeat an identical target in both.

- max_center_shift:

  Maximum coordinate-wise change in physical units.

- maxit:

  Maximum optimizer iterations.

## Value

Refined camera, full fit diagnostics and heldout physical error.
