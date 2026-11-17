# Plot 2D trajectories without joining unobserved or long-gap segments

Plot 2D trajectories without joining unobserved or long-gap segments

## Usage

``` r
aqt_plot_paths(tracks, ..., max_gap_s = Inf)
```

## Arguments

- tracks:

  Validated trajectories.

- ...:

  Passed to graphics::plot.

- max_gap_s:

  Positive maximum elapsed time between connected positions in the
  supplied time_s units; defaults to Inf for legacy plotting. Specify a
  finite threshold to prevent joining long unsampled intervals.

## Value

Invisibly NULL, creating a base graphics plot.

## Details

With finite max_gap_s, paths are split whenever consecutive timestamps
exceed the declared gap. Explicitly unobserved or missing positions also
split paths. Observed singletons are shown as points, not false movement
segments. This is a visualization rule, not physical clock validation.
