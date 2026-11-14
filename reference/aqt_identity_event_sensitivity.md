# Propagate discrete identity assignments to event-aligned fish measures

Computes kinematics separately for each globally consistent identity
scenario and then aggregates observed movement around recorded events.
These are measurement/identity sensitivity outputs, not independent
biological samples or causal estimates.

## Usage

``` r
aqt_identity_event_sensitivity(
  scenarios,
  events,
  outcome = "speed",
  windows = list(baseline = c(-5, 0), response = c(0, 5)),
  unit_cols = c("camera_id", "track_id"),
  max_gap_s = Inf
)
```

## Arguments

- scenarios:

  Identity uncertainty object.

- events:

  Canonical event table.

- outcome:

  Kinematic variable, usually "speed".

- windows:

  Named pre/post event-relative windows.

- unit_cols:

  Identity of observation units within each session.

- max_gap_s:

  Maximum valid movement/time-weighted gap.

## Value

Long per-fish/event/epoch measurements with scenario index.
