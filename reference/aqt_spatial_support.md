# Compare spatial occupancy with explicit equal-window coverage checks

Compare spatial occupancy with explicit equal-window coverage checks

## Usage

``` r
aqt_spatial_support(
  data,
  group_col = "recording",
  phase_col = "phase",
  time_col = "time_s",
  x_col = "x",
  y_col = "y",
  window_width = 3,
  grid = c(8L, 8L),
  min_points_per_window = 10L,
  min_windows = 3L
)
```

## Arguments

- data:

  Data frame of positions, time and recording/phase identifiers.

- group_col, phase_col, time_col, x_col, y_col:

  Source column names.

- window_width:

  Positive source-time window width.

- grid:

  Integer pair giving common x/y grid dimensions per recording.

- min_points_per_window, min_windows:

  Minimum required support.

## Value

Spatial summary and Jensen-Shannon comparisons, marked unsupported
wherever the minimum support is not met. No fish-level inference.
