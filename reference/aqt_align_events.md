# Align trajectories or features with experimental events

Overlapping events generate separate rows; no causal interpretation is
implied. Time must already be on the same clock as the event log.

## Usage

``` r
aqt_align_events(tracks, events, window_s = c(-Inf, Inf))
```

## Arguments

- tracks:

  Trajectory or feature data with session_id/time_s.

- events:

  Event table.

- window_s:

  Time relative to onset, inclusive.

## Value

Event-aligned long data frame.
