# Simulate labelled fish trajectories from a known Gaussian-state HMM

Generates distinct independent tank/fish recording scopes, known latent
state labels and observed Gaussian movement outcomes. Missing outcomes
are explicitly unobserved; truth states remain available for synthetic
evaluation ONLY and must never be treated as real biology. RNG state is
restored upon return to avoid global side effects.

## Usage

``` r
aqt_hmm_simulate_truth(
  n_tanks = 6L,
  fish_per_tank = 2L,
  n_samples = 100L,
  state_means = c(0, 5),
  state_sds = c(0.6, 0.6),
  transition = matrix(c(0.9, 0.1, 0.1, 0.9), 2, 2, byrow = TRUE),
  initial = NULL,
  sampling_dt_s = 0.1,
  missing_fraction = 0,
  seed = 11L
)
```

## Arguments

- n_tanks:

  Number of independent synthetic tanks, \>=4.

- fish_per_tank:

  Number of independently simulated fish per tank.

- n_samples:

  Samples per fish (\>=6); not independent replicates.

- state_means, state_sds:

  Fixed Gaussian emissions for 2..5 ordered states.

- transition:

  Stochastic state transition matrix, row is source.

- initial:

  Optional initial state distribution, uniform by default.

- sampling_dt_s:

  Finite positive inter-frame interval, seconds.

- missing_fraction:

  Bernoulli independent missing outcome probability.

- seed:

  Explicit integer seed, local to this function.

## Value

aqt_hmm_known_truth data frame with provenance, truth_state and
aqt_truth_model metadata; this is a synthetic simulation only.
