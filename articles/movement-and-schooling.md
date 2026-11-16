# Movement, social geometry and spatial occupancy

## Movement and school geometry

Fish trajectories contain an ordered sequence of **observed** positions.
A path’s measured length is therefore a *supported observed distance*,
not necessarily the animal’s true distance traveled through occlusions.

### Core movement analysis

``` r

library(aquaTrajectories)
set.seed(34)
tracks <- aqt_simulate_tracks(n_fish = 5, n_frames = 200)
kin <- aqt_kinematics(tracks, max_gap_s = 0.1)
paths <- aqt_path_summary(tracks, max_gap_s = 0.1)
school <- aqt_group_metrics(tracks, max_gap_s = 0.1)
aqt_plot_paths(tracks)
```

The simulated paths above are not real fish. In actual video analysis,
annotate skipped frames, variable PTS and long support gaps explicitly.

### Spatial group metrics

- [`aqt_group_pairwise_distances()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_group_pairwise_distances.md):
  simultaneous observed pairwise fish positions.
- [`aqt_group_spatial_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_group_spatial_summary.md):
  geometry and group spatial spread.
- [`aqt_group_spatial_edges()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_group_spatial_edges.md):
  threshold-defined proximity networks, **not** inferred friendships or
  dominance.
- [`aqt_zone_occupancy()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_zone_occupancy.md):
  user-defined observed 2D zones.
- [`aqt_voxel_occupancy()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_voxel_occupancy.md):
  observed 3D voxel occupancy, when physical XYZ is valid.
- [`aqt_voxel_entropy()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_voxel_entropy.md):
  conditional occupancy entropy over declared cells.

### Path shape and recurrence

[`aqt_trajectory_dtw()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_trajectory_dtw.md)
and
[`aqt_trajectory_dtw_matrix()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_trajectory_dtw_matrix.md)
compute time-warped distances under declared assumptions.
[`aqt_trajectory_recurrence()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_trajectory_recurrence.md)
quantifies observed-position recurrence with radius and temporal
exclusion rules.

Dense-grid principal components appear in
[`aqt_trajectory_grid_pca()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_trajectory_grid_pca.md).
Irregular sparse sampling is a separate estimation problem handled in
[`aqt_sparse_fpca_fit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sparse_fpca_fit.md)
where `fdapace` is available.

### Visual displays

Find
[`aqt_plot_paths()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_paths.md),
[`aqt_plot_school_dynamics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_school_dynamics.md),
[`aqt_plot_school3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_school3d.md)
and
[`aqt_plot_voxel3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_voxel3d.md)
in the visualization reference.

Proximity alone is not evidence of leadership, preference, stress or
positive welfare.

See [source
protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/docs/SCHOOL_SPATIAL_METHODS.md)
and [source
protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/docs/FUNCTIONAL_TRAJECTORY_METHODS.md).
