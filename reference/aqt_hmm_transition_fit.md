# Estimate HMM transition dynamics while holding Gaussian emissions fixed

Baum-Welch expected transition counts pooled across separately observed
fish segments. Gaussian state means and SDs are externally specified,
NOT fitted. Every fish/session/camera/tank boundary, missing frame and
large time gap is a distinct sequence. A positive symmetric Dirichlet
pseudocount regularizes each transition row and the initial state
distribution. Results describe steps between recorded observations, not
elapsed-time transition rates or independent-tank treatment effects.

## Usage

``` r
aqt_hmm_transition_fit(
  data,
  outcome = "speed",
  state_means,
  state_sds,
  start_transition = NULL,
  start_initial = NULL,
  max_gap_s = 0.5,
  min_segment = 3L,
  max_iter = 200L,
  tol = 1e-07,
  prior = 0.01
)
```

## Arguments

- data:

  Fish outcome data accepted by aqt_hmm_decode.

- outcome:

  Numeric behavioural outcome name.

- state_means:

  Strictly increasing supplied Gaussian means.

- state_sds:

  Strictly positive supplied Gaussian standard deviations.

- start_transition:

  Optional K-by-K starting row-stochastic matrix.

- start_initial:

  Optional starting initial state probability vector.

- max_gap_s, max_iter, min_segment, tol:

  Explicit segment and EM controls.

- prior:

  Positive Dirichlet pseudocount per transition and state.

## Value

aqt_hmm_transition_fit with learned transition/initial, fixed emissions,
likelihood history, training scopes and convergence audit.
