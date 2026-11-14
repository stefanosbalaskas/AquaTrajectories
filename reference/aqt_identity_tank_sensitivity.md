# Propagate identity uncertainty into independently replicated tank contrasts

Repeats the tank-replicated before/after contrast for each discrete
identity scenario. One point estimate per identity draw is reported with
the conditional between-scenario sensitivity distribution; optionally
estimates \*within-scenario\* cluster-bootstrap percentile intervals by
resampling tanks rather than frames. These two variance sources are kept
separate and MUST NOT be interpreted as a fully combined confidence
interval or causal treatment effect.

## Usage

``` r
aqt_identity_tank_sensitivity(
  scenarios,
  events,
  windows = list(baseline = c(-5, 0), response = c(0, 5)),
  outcome = "speed",
  cluster_bootstrap_draws = 100L,
  seed = 101L
)
```

## Arguments

- scenarios:

  Identity scenario object carrying tank_id and treatment.

- events:

  Event table.

- windows:

  Named baseline and response windows.

- outcome:

  Kinematic outcome.

- cluster_bootstrap_draws:

  Bootstrap replications \>=100 per identity scenario. Choose 100 for a
  quick demonstration.

- seed:

  Random seed for separate tank bootstrap, preserving RNG.

## Value

List with per-draw tank contrasts and identity sensitivity.
