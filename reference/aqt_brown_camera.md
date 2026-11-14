# Define measured Brown-Conrady perspective lens distortion coefficients

Maps normalized pinhole coordinates through radial k1,k2,k3 and
tangential p1,p2 terms. Requires an externally fitted camera K. This
model is NOT appropriate for unconverted GoPro fisheye/
superview/wide-angle source frames unless separately demonstrated.

## Usage

``` r
aqt_brown_camera(
  K,
  k1 = 0,
  k2 = 0,
  p1 = 0,
  p2 = 0,
  k3 = 0,
  max_normalized_radius = 2
)
```

## Arguments

- K:

  Positive-focal-length pinhole intrinsic 3-by-3 matrix.

- k1, k2, k3:

  Radial coefficients in normalized coordinate units.

- p1, p2:

  Tangential coefficients.

- max_normalized_radius:

  Validated maximum normalized ray radius.

## Value

aqt_brown_camera with calibration_certified=FALSE.
