# Compare three-dimensional reconstruction errors on held-out targets

Two-column publication panel per method: nonnegative Euclidean XYZ
position-error histogram and an axonometric map of surveyed target
locations coloured by their error. It does not substitute for a signed
inter-target distance-error distribution, and a plotted residual is not
independent calibration certification.

## Usage

``` r
aqt_plot_calibration_comparison(
  data,
  units = c("cm", "m"),
  require_holdout = TRUE
)
```

## Arguments

- data:

  Data.frame containing method,target_id,partition and six
  truth/prediction XYZ coordinates in explicitly stated units.

- units:

  Either cm or m; must match supplied physical coordinates.

- require_holdout:

  Require explicit partition==holdout (default TRUE). Rows marked fit
  are never scored; overlapping target IDs between fit and holdout in
  the same method cause an error.

## Value

Invisibly a per-method error summary. Source measurements and external
survey accuracy are not automatically certified.
