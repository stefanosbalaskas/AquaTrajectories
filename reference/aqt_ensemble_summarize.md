# Summarize across conditional trajectory measurement-error scenarios

Each group should have at most one value per simulated draw. The
quantile interval is a sensitivity interval under the supplied error
assumptions, NEVER a validated confidence interval for treatment.

## Usage

``` r
aqt_ensemble_summarize(
  draws,
  value_col,
  group_cols = c("session_id", "camera_id", "track_id"),
  level = 0.95
)
```

## Arguments

- draws:

  Long data frame from aqt_ensemble\_\* summary.

- value_col:

  Measurement column, such as mean_speed or value.

- group_cols:

  Identity/event columns defining one estimand.

- level:

  Fraction within the central empirical quantile interval.

## Value

Per-group conditional mean, SD, quantiles and draw count.
