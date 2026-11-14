# Thresholded fish-school spatial association edge list

Every edge means two visible fish were within the declared Euclidean
distance at exactly the same timestamp. Association is not leadership,
causality, attraction, social preference or consistent individual
identity.

## Usage

``` r
aqt_group_spatial_edges(tracks, radius, max_pairs = 1000000L)
```

## Arguments

- tracks:

  Canonical 2D/3D tracks.

- radius:

  Positive proximity threshold in coordinate units.

- max_pairs:

  Maximum candidate pairs before filtering.

## Value

Long edge list with pairwise distances and timestamp.
