# Summarize fish behaviour in named windows around recorded events

This is a descriptive analysis of already tracked/validated data. Event
windows are relative to onset and use intervals \[start,end); the final
epoch includes its right endpoint. Arbitrarily dense frames are NOT
independent experimental replicates. For irregular sample intervals
choose time_weighted where possible.

## Usage

``` r
aqt_event_epoch_summary(
  data,
  events,
  outcome,
  windows = list(baseline = c(-120, 0), response = c(0, 120), recovery = c(120, 600)),
  unit_cols = c("camera_id", "track_id"),
  estimator = c("sample_mean", "time_weighted"),
  min_points = 2L,
  max_gap_s = Inf
)
```

## Arguments

- data:

  Table with session_id, time_s, numeric outcome and unit columns.

- events:

  Event table with session_id,event_id,start_s,end_s.

- outcome:

  Name of numeric feature (e.g. speed).

- windows:

  Named list of finite length-two offset vectors, in seconds.

- unit_cols:

  Columns that identify the observational unit within a session, such as
  tank_id, camera_id, track_id; include treatment only if it is constant
  within the observational unit.

- estimator:

  sample_mean or trapezoid time_weighted mean.

- min_points:

  Minimum finite observed points for an estimate.

- max_gap_s:

  Largest interval for trapezoid weighting; missing or non-observed
  observations also break a time-weighted segment.

## Value

Descriptive per-session/event/epoch/unit means, counts and time spans.
