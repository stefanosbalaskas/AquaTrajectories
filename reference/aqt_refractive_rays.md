# Trace image pixels through a single ideal planar refractive interface

Ray directions follow vector Snell refraction and return ray origins on
the interface plus directions in the second homogeneous medium. No
automatic calibration, distortion or glass-thickness compensation.

## Usage

``` r
aqt_refractive_rays(camera, pixels)
```

## Arguments

- camera:

  aqt_refraction_camera.

- pixels:

  Numeric n-by-2 observed undistorted pixel coordinates.

## Value

Data frame of refracted ray origin/direction and valid flag.
