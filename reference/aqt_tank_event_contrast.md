# Estimate a tank-replicated difference in event-related changes

For each tank, mean values from the specified before/after epochs are
contrasted. The between-group estimand is mean(change in treatment) -
mean(change in control), giving every independent tank equal weight.
Bootstrap resampling is performed \*over tanks within treatment\*, never
over individual video frames or fish. This is a descriptive difference-
in-differences-like association, not causal identification by itself.

## Usage

``` r
aqt_tank_event_contrast(
  epochs,
  treatment_levels = c("control", "treatment"),
  baseline = "baseline",
  response = "response",
  tank_col = "tank_id",
  treatment_col = "treatment",
  epoch_col = "epoch",
  value_col = "value",
  draws = 999L,
  level = 0.95,
  seed = 7L
)
```

## Arguments

- epochs:

  Summaries containing tank_id, treatment, epoch, value.

- treatment_levels:

  Exactly c(control_label,treatment_label).

- baseline, response:

  Names of before and after event epochs.

- tank_col, treatment_col, epoch_col, value_col:

  Column names.

- draws:

  Number of tank-level bootstrap replications, \>=100.

- level:

  Central percentile interval mass.

- seed:

  Integer seed; RNG state is preserved.

## Value

List of contrast, percentile interval and per-tank changes.
