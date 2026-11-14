# Multivariate dynamic time warping for validated 2D/3D fish paths

Computes Euclidean position distance at each aligned sample using
deterministic dynamic programming. The time-warping path is not physical
synchronized time, a fish identity match, or a causal mechanism. Input
trajectories must have complete observed coordinates, consistent units
and a single scoped fish ID each. Never interpolates missing points.

## Usage

``` r
aqt_trajectory_dtw(track_a, track_b, window = Inf, max_gap_s = Inf)
```

## Arguments

- track_a, track_b:

  A single validated 2D or 3D aqt_tracks path each.

- window:

  Optional nonnegative Sakoe-Chiba band in sample indices; Inf (default)
  permits unrestricted warping.

- max_gap_s:

  Largest allowed sampling interval in either path.

## Value

List with total cost, cost per alignment pair, and alignment index/time
path. Units equal the trajectory coordinate units.
