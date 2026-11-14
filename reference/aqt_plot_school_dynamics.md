# Plot observed school geometry over time without frame-level inference

A descriptive trajectory of group-level distances and spatial structure.
Different fish counts and tracking quality can change the measures.

## Usage

``` r
aqt_plot_school_dynamics(
  summary,
  session_id,
  camera_id,
  metric = c("radius_gyration", "mean_pair_distance", "group_extent")
)
```

## Arguments

- summary:

  Table returned by aqt_group_spatial_summary().

- session_id, camera_id:

  One scoped group.

- metric:

  radius_gyration, mean_pair_distance or group_extent.

## Value

Selected group summary invisibly; creates base graphics plot.
