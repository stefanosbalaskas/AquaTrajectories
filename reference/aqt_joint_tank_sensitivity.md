# Compare tank-level event contrasts under joint optical/identity scenarios

Reports one tank-replicated treatment contrast PER measurement scenario,
plus separate within-scenario bootstrap intervals based on resampled
independently treated tanks. The distribution across scenarios is a
CONDITIONAL SENSITIVITY interval, not a validated combined confidence
interval or causal estimate.

## Usage

``` r
aqt_joint_tank_sensitivity(
  scenarios,
  events,
  outcome = "speed",
  windows = list(baseline = c(-3, 0), response = c(0, 3)),
  tank_bootstrap_draws = 100L,
  seed = 103L,
  max_gap_s = Inf
)
```

## Arguments

- scenarios:

  Joint optical/ID uncertainty object.

- events:

  External event log.

- outcome:

  Kinematic outcome.

- windows:

  Baseline and response windows.

- tank_bootstrap_draws:

  Replications \>= 100 per scenario.

- seed:

  Bootstrap seed, independent of optical/ID draw seed.

- max_gap_s:

  Maximum permissible interval between swimming observations. Explicit
  gaps remain invalid; use a finite value appropriate to frame rate.

## Value

List of per-scenario tank contrasts and conditional quantiles.
