# Invert a known Brown perspective lens distortion with residual QC

Iteratively solves radial+tangential distortion for normalized pinhole
pixels. Non-converged or out-of-FOV observations remain explicitly
invalid; no invented coordinates are returned.

## Usage

``` r
aqt_brown_undistort_pixels(
  model,
  pixels,
  max_iter = 60L,
  tolerance_norm = 1e-12,
  max_roundtrip_px = 1e-05
)
```

## Arguments

- model:

  aqt_brown_camera with separately measured K and coefficients.

- pixels:

  Numeric n-by-2 distorted pixel matrix.

- max_iter:

  Integer 1..200 fixed-point iterations.

- tolerance_norm:

  Required normalized-coordinate step convergence.

- max_roundtrip_px:

  Maximum acceptable forward reprojection residual.

## Value

Data frame undistorted x_px/y_px, valid, iterations and forward
roundtrip pixel error; calibration still not certified.
