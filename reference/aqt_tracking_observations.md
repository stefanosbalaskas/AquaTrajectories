# Validate manually labelled or predicted point tracks for benchmarking

Ground truth must be independently annotated and use stable identities
within each video. Frame IDs must be nonnegative integers on a common
reference clock; partial human annotations must be evaluated only on
their annotated frames.

## Usage

``` r
aqt_tracking_observations(data)
```

## Arguments

- data:

  Data frame with session_id, camera_id, frame_id, track_id, x and y;
  optionally class_id. Coordinates must use the same scale.

## Value

Canonical per-frame tracking observations.
