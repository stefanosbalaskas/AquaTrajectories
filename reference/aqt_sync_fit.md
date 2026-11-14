# Estimate camera offset and drift from shared sync events

Estimate camera offset and drift from shared sync events

## Usage

``` r
aqt_sync_fit(markers, reference_camera)
```

## Arguments

- markers:

  Data frame camera_id, marker_id, time_s.

- reference_camera:

  Camera defining the common clock.

## Value

Table of affine clock mapping coefficients; one marker only identifies
offset, not drift.
