# Audit physical ray residuals and clock skew in refractive 3D fish tracks

All summaries are diagnostics conditional on the supplied camera model
and fish correspondences; neither low ray error nor successful R tests
establish absolute calibrated 3D world-position accuracy.

## Usage

``` r
aqt_refractive_track_quality(tracks)
```

## Arguments

- tracks:

  Output of aqt_refractive_reconstruct_tracks().

## Value

Per-session valid counts, missing fraction and ray/clock QC.
