# Recalculate event-aligned fish behaviour for every joint optical/ID draw

No video frames are treated as independent experimental replicates.

## Usage

``` r
aqt_joint_event_sensitivity(
  scenarios,
  events,
  outcome = "speed",
  windows = list(baseline = c(-3, 0), response = c(0, 3)),
  unit_cols = c("camera_id", "track_id"),
  max_gap_s = Inf
)
```

## Arguments

- scenarios:

  aqt_joint_refractive_scenarios.

- events:

  External event log.

- outcome:

  Numeric kinematic outcome such as speed.

- windows:

  Named event-relative nonoverlapping intervals.

- unit_cols:

  Columns identifying observational units.

- max_gap_s:

  Largest permissible movement segment.

## Value

Long conditional per-draw event epoch outcomes.
