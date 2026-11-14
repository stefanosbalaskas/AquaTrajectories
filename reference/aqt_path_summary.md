# Per-individual path summaries

Per-individual path summaries

## Usage

``` r
aqt_path_summary(tracks, max_gap_s = Inf)
```

## Arguments

- tracks:

  An aqt_tracks object.

- max_gap_s:

  Maximum observed time interval.

## Value

One row per session/camera/track with path length, valid duration,
time-weighted mean speed, and observed fraction.
