# Inspect reconstructed 3D trajectory quality using two diagnostic plots

Produces a distribution of reprojection RMSE and a distribution of
between-camera time skew. These are diagnostics, not metrological proof.

## Usage

``` r
aqt_plot_reconstruction_qc(reconstructed)
```

## Arguments

- reconstructed:

  aqt_tracks with stereo QC columns.

## Value

Per-session reconstruction summary invisibly.
