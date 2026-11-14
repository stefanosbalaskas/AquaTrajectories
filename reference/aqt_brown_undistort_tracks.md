# Preserve tracker provenance while undistorting canonical fish video tracks

Applies an externally fitted Brown perspective lens model to one
pixel-space aqt_tracks object, retaining exact original detector pixels,
timestamps, IDs and an explicit per-observation roundtrip error. Unknown
and invalid fish positions stay unobserved. The resulting 2D pinhole
pixels can enter the existing refractive multi-camera reconstruction
only after independent cross-view identity and synchronization checks.

## Usage

``` r
aqt_brown_undistort_tracks(tracks, lens, ...)
```

## Arguments

- tracks:

  aqt_tracks in 2D image coordinates and px units.

- lens:

  aqt_brown_camera with camera-matched intrinsic K.

- ...:

  Inversion thresholds for aqt_brown_undistort_pixels().

## Value

aqt_tracks containing undistorted x/y and original measured detector
pixels in distorted_x_px/distorted_y_px.
