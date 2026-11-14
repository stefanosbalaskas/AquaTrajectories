# Trace distorted camera pixels through a measured flat-port glass model

Composes explicit Brown perspective undistortion with the separately
parameterized two-interface air-glass-water Snell model. Does not
certify parameters or infer correct cross-camera fish identities.

## Usage

``` r
aqt_flatport_rays_distorted(camera, lens, pixels, ...)
```

## Arguments

- camera:

  aqt_flatport_camera.

- lens:

  aqt_brown_camera with exactly matching intrinsic K.

- pixels:

  Distorted n-by-2 source pixels; unknown rows are invalid.

- ...:

  Optional inversion thresholds passed to aqt_brown_undistort_pixels.

## Value

Underwater physical rays, undistortion validity and forward roundtrip
pixel diagnostic, with invalid rays explicit.
