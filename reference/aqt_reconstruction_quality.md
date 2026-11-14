# Summarize quality of reconstructed stereo fish positions

Summarize quality of reconstructed stereo fish positions

## Usage

``` r
aqt_reconstruction_quality(reconstructed)
```

## Arguments

- reconstructed:

  aqt_tracks returned by aqt_reconstruct_3d.

## Value

Per-session counts, missing proportions, reprojection error and
synchronized time-skew diagnostics. A low reprojection error is not
proof of absolute XYZ accuracy.
