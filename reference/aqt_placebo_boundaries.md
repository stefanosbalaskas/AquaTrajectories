# Construct within-recording placebo boundaries, without pseudo-p-values

Construct within-recording placebo boundaries, without pseudo-p-values

## Usage

``` r
aqt_placebo_boundaries(
  data,
  group_col = "recording",
  phase_col = "phase",
  time_col = "time_s",
  value_col = "speed",
  window_width = 3,
  min_windows_per_side = 3L
)
```

## Arguments

- data:

  Source movement table.

- group_col, phase_col, time_col, value_col:

  Column names.

- window_width:

  Positive source-time bin width.

- min_windows_per_side:

  Minimum valid windows on each side of a cut.

## Value

Eligible within-file cut contrasts, not an independent null sample.
