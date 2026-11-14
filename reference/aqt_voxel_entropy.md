# Shannon occupancy entropy for a 3D voxelized fish tank

Counts are conditioned on positions inside the supplied voxel grid.
Positions outside the grid are reported separately. These are observed
sample-based entropies and not continuous dwell-time uncertainty
estimates.

## Usage

``` r
aqt_voxel_entropy(voxels)
```

## Arguments

- voxels:

  Table returned by aqt_voxel_occupancy().

## Value

Per scoped group/fish entropy in bits and normalized entropy.
