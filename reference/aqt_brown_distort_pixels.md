# Apply a known Brown radial/tangential lens distortion model

Forward-maps undistorted pinhole pixels into a modeled distorted
detector pixel domain, respecting the declared normalized FOV radius.
Rows with unknown coordinates remain invalid, not imputed.

## Usage

``` r
aqt_brown_distort_pixels(model, pixels)
```

## Arguments

- model:

  aqt_brown_camera.

- pixels:

  Numeric n-by-2 undistorted pinhole coordinates.

## Value

Data frame distorted x_px,y_px,valid, not a fish track.
