# Compare manually verified underwater landmark positions with traced rays

Measures minimum perpendicular distance between observed refracted rays
and independent 3D target landmarks. It is a physical consistency check,
not proof of calibration unless landmarks and their measurement accuracy
have been independently established.

## Usage

``` r
aqt_refractive_landmark_qc(camera, pixels, landmarks_xyz)
```

## Arguments

- camera:

  aqt_refraction_camera.

- pixels:

  n-by-2 observed undistorted pixels of known landmarks.

- landmarks_xyz:

  Matched known n-by-3 world-space reference points.

## Value

Per-landmark perpendicular ray residual and summary RMSE.
