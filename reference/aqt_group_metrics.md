# Group cohesion and 2D/3D directional polarization

Metrics require simultaneous observations at identical timestamps.
Polarization requires at least two valid non-zero velocity vectors.

## Usage

``` r
aqt_group_metrics(tracks, max_gap_s = Inf)
```

## Arguments

- tracks:

  An aqt_tracks object.

- max_gap_s:

  Largest movement interval.

## Value

Group metrics per session/camera/timestamp.
