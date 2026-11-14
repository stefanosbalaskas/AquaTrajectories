# Summarize sampled spatial occupancy within user-defined rectangles

Uses the proportion of valid sampled positions in each rectangular zone,
not a continuous dwell-time estimator. Overlapping zones are permitted
and may each contain the same observation. Coordinate units must match
tracks.

## Usage

``` r
aqt_zone_occupancy(tracks, zones)
```

## Arguments

- tracks:

  Validated 2D or 3D aqt_tracks.

- zones:

  Table with zone_id, xmin, xmax, ymin, ymax and optionally zmin, zmax;
  omit z bounds to ignore height even for 3D.

## Value

Per scoped fish and zone, n_valid, n_in_zone, sample_fraction.
