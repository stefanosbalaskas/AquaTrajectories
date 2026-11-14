# Triangulate externally paired fish observations as underwater rays

Finds the midpoint of shortest positive-length segments between
corresponding refracted rays, reporting separation error. This is
geometric triangulation, not automatic fish identity association. Ray
separation in physical units is a consistency diagnostic, not
independent position accuracy or statistical interval coverage.

## Usage

``` r
aqt_refractive_triangulate(
  camera_a,
  camera_b,
  pixels_a,
  pixels_b,
  max_separation = Inf
)
```

## Arguments

- camera_a, camera_b:

  Two compatible explicitly parameterized refractive cameras, with
  matching world-coordinate units.

- pixels_a, pixels_b:

  Explicitly corresponding undistorted n-by-2 source-image pixel
  coordinates.

- max_separation:

  Optional nonnegative maximum ray separation in the camera's physical
  units; exceeding it invalidates an estimate.

## Value

XYZ midpoint, ray separation, ray parameters, and validity.
