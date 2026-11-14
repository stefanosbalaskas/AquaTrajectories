# Convert 2D image coordinates using an externally measured constant scale

This assumes a geometrically valid planar scale. It does NOT correct
camera perspective, fish depth, lens distortion or water/glass
refraction. The function preserves original source pixel coordinates for
auditing.

## Usage

``` r
aqt_scale_calibrate(tracks, pixels_per_cm)
```

## Arguments

- tracks:

  Two-dimensional aqt_tracks in image coordinates and pixels.

- pixels_per_cm:

  Positive independently measured scale.

## Value

Calibrated planar aqt_tracks in cm, tank coordinates.
