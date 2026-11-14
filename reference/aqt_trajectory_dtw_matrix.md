# Pairwise DTW distance matrix across independently scoped fish tracks

Each fish-camera-session scope contributes one path. Distances can mix
sessions only as shape comparisons, not as permanent fish identities.
All paths must be complete, in compatible position units and dimensions.
The distance is the total minimum alignment cost, not average cost.

## Usage

``` r
aqt_trajectory_dtw_matrix(tracks, window = Inf, max_gap_s = Inf)
```

## Arguments

- tracks:

  Canonical aqt_tracks with at least two scoped fish paths.

- window:

  DTW window in sample indices.

- max_gap_s:

  Maximum valid observation interval in any path.

## Value

Symmetric numeric matrix of total alignment costs.
