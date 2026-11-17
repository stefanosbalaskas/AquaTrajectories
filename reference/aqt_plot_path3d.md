# Plot true 3D trajectories with explicit missing/gap segmentation

A 3D scene draws measured XYZ points only. Unobserved numeric points and
timestamps separated by more than max_gap_s never form a path segment.
Single observed points are rendered as points. The caller, not this
renderer, must verify true physical XYZ and observation clocks.

## Usage

``` r
aqt_plot_path3d(tracks, max_gap_s = Inf)
```

## Arguments

- tracks:

  Validated 3D tank trajectories.

- max_gap_s:

  Positive maximum elapsed time between connected observations; Inf
  preserves the legacy time-gap policy.

## Value

Invisibly NULL; opens optional rgl scene.
