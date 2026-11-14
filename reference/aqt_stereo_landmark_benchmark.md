# Evaluate refractive stereo coordinates against independent physical truth

Unlike minimum ray separation, this reports absolute differences from
externally measured 3D landmark positions. Failed triangulations are
always included in the denominator and marked invalid.

## Usage

``` r
aqt_stereo_landmark_benchmark(
  camera_a,
  camera_b,
  pixels_a,
  pixels_b,
  landmarks_xyz,
  landmark_id = NULL,
  max_separation = Inf
)
```

## Arguments

- camera_a, camera_b:

  Compatible refractive camera models.

- pixels_a, pixels_b:

  Matched undistorted n-by-2 camera pixel matrices.

- landmarks_xyz:

  Independently measured n-by-3 physical XYZ matrix.

- landmark_id:

  Optional unique landmark identifiers, n elements.

- max_separation:

  Maximum allowed closest-ray distance in physical camera units.

## Value

Per-landmark XYZ error and physical RMSE, MAE, bias, missingness, valid
count and independent-truth diagnostics.
