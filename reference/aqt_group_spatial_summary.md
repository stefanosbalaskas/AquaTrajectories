# Simultaneous fish-school centroid, radius and spatial extent

The radius of gyration is root mean squared Euclidean distance from the
school centroid. Extent is the maximum pairwise distance. A group with
only one visible fish has radius zero and undefined pairwise extent;
only groups with \>= min_fish are returned.

## Usage

``` r
aqt_group_spatial_summary(tracks, min_fish = 2L)
```

## Arguments

- tracks:

  Observed validated fish trajectories.

- min_fish:

  Required number of simultaneously visible fish (\>=2).

## Value

Centroid XYZ, radius of gyration, mean pairwise distance and extent.
