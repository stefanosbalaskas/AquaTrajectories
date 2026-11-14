# Propagate spatial measurement scenarios into fish path statistics

Returns one row per scoped fish and measurement-error draw. These are
conditional sensitivity calculations; the between-draw variance is not
biological or independent-tank sampling variance.

## Usage

``` r
aqt_ensemble_path_summary(ensemble, max_gap_s = Inf)
```

## Arguments

- ensemble:

  aqt_trajectory_ensemble.

- max_gap_s:

  Maximum valid movement segment for path summaries.

## Value

Long data frame of path length and time-weighted mean speed.
