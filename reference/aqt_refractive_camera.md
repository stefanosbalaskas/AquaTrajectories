# Define one calibrated ideal air-water planar refractive camera

All parameters are user-supplied calibration quantities, NOT
automatically calibrated. This model applies to exactly one ideal
interface between two homogeneous media. It MUST NOT be used as a
physically exact model for flat glass windows (two interfaces), dome
ports, nonplanar surfaces, lens distortion or rolling shutter.

## Usage

``` r
aqt_refractive_camera(
  K,
  R_c2w,
  center,
  plane_point,
  plane_normal,
  n_before = 1,
  n_after = 1.333,
  units = "cm"
)
```

## Arguments

- K:

  Finite invertible 3x3 camera intrinsic matrix with K\[3,\]=c(0,0,1).

- R_c2w:

  Rotation (camera-to-world) with orthonormal columns.

- center:

  Camera optical centre in world coordinates.

- plane_point:

  Point on the ideal planar optical interface.

- plane_normal:

  Unit direction from the camera-side medium to the target medium. It is
  normalized internally.

- n_before, n_after:

  Positive refractive indices of the two media.

- units:

  World-coordinate units, "cm" or "m".

## Value

An aqt_refraction_camera object.
