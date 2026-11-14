# Generate unreviewed cross-camera refractive fish match candidates

Generate geometrically plausible fish-pair hypotheses by tracing
camera-local detections through two calibrated refractive models.

## Usage

``` r
aqt_refractive_view_candidates(view_a, view_b, camera_a, camera_b,
  max_skew_s = 0.02, max_ray_separation = 0.5,
  max_candidates = 100000L)
```

## Arguments

- view_a, view_b:

  Two valid camera-local 2D image-space pixel `aqt_tracks`.

- camera_a, camera_b:

  Externally calibrated compatible refractive camera models.

- max_skew_s:

  Maximum timestamp skew after externally applied camera alignment.

- max_ray_separation:

  Maximum physically permitted closest-ray residual.

- max_candidates:

  Maximum number of time-compatible fish candidate pairs.

## Value

Source-paired stereo candidate data frame with image, time, fish track,
refractive XYZ, ray residual and validity. No biological identity
certified.

## Details

Camera exposure synchronization, intrinsic/extrinsic calibration and
animal identity are external responsibilities. Original source video
data are never used as ground-truth identities by this function.
