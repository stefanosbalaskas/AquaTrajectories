# Recompute behavioural event epochs across detection-loss scenarios

Recomputes kinematics and event-aligned descriptive statistics for every
conditional detection dropout scenario. Does not interpret fish frames
as independent treatment replication or estimate validated causal,
calibrated uncertainty or welfare effects.

## Usage

``` r
aqt_detection_event_sensitivity(scenarios, events, outcome = "speed",
  windows = list(baseline = c(-3, 0), response = c(0, 3)),
  max_gap_s = Inf, min_points = 1L)
```

## Arguments

- scenarios:

  Output from `aqt_detection_dropout_scenarios`.

- events:

  External event table with session_id, event_id, start_s, end_s.

- outcome:

  Numeric kinematic outcome (default `speed`).

- windows:

  Named chronological, non-overlapping time windows relative to events.

- max_gap_s:

  Maximum valid observed gap in seconds for kinematics.

- min_points:

  Minimum observed finite points to estimate each event epoch.

## Value

Long per-draw, per-fish external-event descriptive summaries with
calibration and independent tank treatment-effect flags set to false.
