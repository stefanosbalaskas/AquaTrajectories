# Plot 3D occupancy voxels as an observed-sample point cloud

Marker sizes represent relative observed sample frequency in grid cells.
This is not a voxel mesh, a continuous dwell-time estimate, or a
confidence region for each fish's position.

## Usage

``` r
aqt_plot_voxel3d(voxels)
```

## Arguments

- voxels:

  Table from aqt_voxel_occupancy, for exactly one group/fish.

## Value

Observed nonempty grid voxels invisibly; opens optional rgl plot.
