# Estimate 3D spatial occupancy on an explicitly defined voxel grid

Counts observed calibrated fish positions inside fixed rectangular
voxels. Does not interpolate between samples and does not measure
continuous residence time; irregular temporal sampling can bias these
sample-based fractions. All out-of-range positions are reported.

## Usage

``` r
aqt_voxel_occupancy(tracks, breaks, by = c("group", "fish"))
```

## Arguments

- tracks:

  Validated 3D tank-space trajectories.

- breaks:

  Named list of increasing numeric x, y and z break vectors, in the same
  world-coordinate units as tracks.

- by:

  fish for per-individual occupancy, or group for shared occupancy
  within session/camera.

## Value

One row per voxel and analysis group with n_samples, sample_fraction,
n_valid and n_outside.
