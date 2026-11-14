# Propagate spatial noise scenarios into event-aligned fish behaviour

Recomputes movement metrics independently for every trajectory draw,
then applies the existing event-epoch summarizer. No before/after
treatment effect is claimed by this measurement-only procedure.

## Usage

``` r
aqt_ensemble_event_summary(
  ensemble,
  events,
  outcome = "speed",
  windows = list(baseline = c(-120, 0), response = c(0, 120)),
  estimator = c("sample_mean", "time_weighted"),
  max_gap_s = Inf,
  min_points = 2L
)
```

## Arguments

- ensemble:

  aqt_trajectory_ensemble.

- events:

  Event log.

- outcome:

  A numeric kinematic column such as speed or acceleration.

- windows:

  Named list of ordered event-relative time windows.

- estimator:

  sample_mean or time_weighted.

- max_gap_s:

  Largest movement and weighted-event segment interval.

- min_points:

  Minimum valid epoch samples.

## Value

Event epochs per fish and scenario draw.
