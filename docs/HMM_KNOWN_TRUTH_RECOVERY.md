# Wave 8F — known-truth fish-state transition recovery benchmark

## Purpose

AquaTrajectories now contains a conditional Gaussian HMM decoder (Wave 8D)
and fixed-Gaussian-emission Baum-Welch transition estimation (Wave 8E).
Wave 8F adds a reproducible, **synthetic-only** regression environment
with the hidden states and true parameters known in advance.

The aims are mathematical recoverability, explicit handling of missing
video observations, and truly disjoint tank-level model evaluation.
The generator does NOT reproduce physical fish locomotion, GoPro optical
errors or actual stress/welfare state labels.

## Synthetic experiment

~~~r
library(aquaTrajectories)
T <- matrix(c(.90,.10,.15,.85),2,2,byrow=TRUE)
simulated <- aqt_hmm_simulate_truth(
  n_tanks=8,fish_per_tank=2,n_samples=100,
  state_means=c(.5,4),state_sds=c(.4,.6),
  transition=T,initial=c(.5,.5),
  sampling_dt_s=.1,missing_fraction=.03,seed=41
)
audit <- aqt_hmm_recovery_audit(
  simulated,training_tanks=sprintf("T%03d",1:6),
  max_iter=150,prior=.01
)
audit$truth_transition
audit$fitted_transition
audit$transition_mean_abs_error
audit$heldout_viterbi_truth_accuracy
audit$heldout_confusion
audit$heldout_mean_loglik_per_sample
~~~

## Statistical contract

Each tank has a synthetic session and each fish its own track ID.
Hidden state z_(t+1) is sampled from the truth transition matrix row
of z_t. The observed movement value is Gaussian conditional on z_t,
using exactly the externally supplied state means and SDs.

A Bernoulli missingness mechanism masks observed movement values
without changing hidden truth. These conditions are intentionally
simple and NOT a model of nonrandom fish detection failure. The
simulator uses a local seed, restores the caller's .Random.seed even
if the code encounters an error, and labels its output
`aqt_hmm_known_truth` with explicit synthetic-only provenance.

`aqt_hmm_recovery_audit()` requires at least two training tanks and two
different heldout tanks. It fits transition and initial probabilities
on training tanks only, keeping Gaussian emissions fixed to their
known true parameters. On independent heldout tanks it computes:
- elementwise transition matrix absolute error and mean/max errors;
- initial state distribution mean absolute error;
- Viterbi-versus-true latent state accuracy among supported samples;
- full state-by-state heldout confusion matrix and conditional recalls;
- total and per-modelled-sample heldout observed-data log likelihood;
- counts of modelled/missing/unsupported samples and independent tanks.

The emissions are known here, so this is not an evaluation of emission
parameter recovery. The reference states are true only by construction,
so accuracy against them is **not** an external animal annotation
benchmark. No treatment or tank-level causal effects are generated
or inferred by this module.

## Prepublication validation still required

1. Multiple simulation regimes spanning overlapping emissions,
   rare states, noisy transition matrices and realistic missingness.
2. Empirically validated models of occlusion, shadow-related detector
   failures, cross-view fish swaps and irregular exposure times.
3. Real video records annotated by independent fish behaviour experts.
4. External underwater optical known-distance/XYZ calibration,
   independent tanks and true out-of-study camera systems.
5. Model comparison, goodness-of-fit, uncertainty coverage, and
   defensible species-specific physiological interpretation.

Successful software tests or excellent synthetic recovery do not
establish any of these external scientific facts.
