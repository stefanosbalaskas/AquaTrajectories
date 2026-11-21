# Draw a QC-aware publication specification on the current R graphics device

This renders only the audited, sealed figure specification. The plot
does not create an external file; use aqt_viz2_export for hash-linked
artifacts. Spatial paths connect ONLY explicitly eligible QC2 source-row
pairs; failed steps are not joined by any line, even if source points
exist. Speed is the full original Euclidean step length / elapsed
seconds; xz/yz projections do not silently change the velocity
denominator.

## Usage

``` r
aqt_viz2_draw(spec)
```

## Arguments

- spec:

  Source-linked aqt_viz2_spec.

## Value

The specification invisibly, after drawing on the current device.
