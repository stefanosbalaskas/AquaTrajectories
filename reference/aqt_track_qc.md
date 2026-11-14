# Track QC flags for missing positions, time gaps, and implausible motion

Track QC flags for missing positions, time gaps, and implausible motion

## Usage

``` r
aqt_track_qc(tracks, max_gap_s, max_speed = NULL)
```

## Arguments

- tracks:

  An aqt_tracks object.

- max_gap_s:

  Maximum expected sample interval.

- max_speed:

  Optional velocity threshold in position units/s.

## Value

Observation-level QC data, not a calibrated error estimate.
