# Audit Gaussian HMM transition and state recovery on unseen synthetic tanks

Fits Wave 8E's fixed-emission transition model on selected synthetic
tanks, then predicts previously unseen simulation tanks. The truth
emission parameters are supplied to the fitting stage by design. This
benchmark checks code/estimation recoverability, NOT real fish state
calibration, detection uncertainty or independent animal welfare.

## Usage

``` r
aqt_hmm_recovery_audit(
  simulated,
  training_tanks,
  min_segment = 3L,
  max_gap_s = NULL,
  max_iter = 150L,
  tol = 1e-06,
  prior = 0.01
)
```

## Arguments

- simulated:

  aqt_hmm_known_truth from aqt_hmm_simulate_truth.

- training_tanks:

  Distinct tank IDs for training; \>=2 training and \>=2 other strictly
  heldout tank IDs required.

- min_segment:

  Minimum consecutive observed points.

- max_gap_s:

  Default is 1.01 times the simulated sample interval.

- max_iter, tol, prior:

  Estimation settings for Wave 8E.

## Value

aqt_hmm_recovery_audit with truth/estimated parameters, heldout
accuracy/confusion and conditional predictive likelihood.
