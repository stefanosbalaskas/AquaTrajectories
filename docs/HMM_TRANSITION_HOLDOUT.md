# Wave 8E — fixed-emission Gaussian HMM transition estimation

## Scientific scope

Wave 8D supplies conditional forward-backward and Viterbi state decoding
under an externally declared Gaussian HMM. Wave 8E estimates the
**initial-state distribution** and discrete **sample-step transition
matrix** by expectation-maximization (Baum-Welch) while keeping Gaussian
emission means and SDs fixed. This deliberately separates mathematical
model estimation from validating fish behavioural-state labels.

No species-specific emission learning, animal stress assessment,
continuous-time hazard estimation, hierarchical treatment inference
or physical XYZ measurement-error calibration is claimed.

## Workflow

~~~r
library(aquaTrajectories)
fit <- aqt_hmm_transition_fit(
  train_fish,
  outcome="speed",
  state_means=c(.5,3),
  state_sds=c(.3,.6),
  max_gap_s=.2,min_segment=3,
  max_iter=200,tol=1e-7,prior=.01
)
print(fit$transition)
print(fit$initial)
print(fit$loglik_history)
print(fit$converged)

# Heldout fish data from tanks not present in train_fish:
heldout <- aqt_hmm_holdout_score(
  test_fish,fit,require_disjoint_tanks=TRUE
)
print(heldout$mean_loglik_per_sample)
~~~

## Mathematical details

The E step computes each independently segmented sequence's
observed-data log likelihood, posterior occupancy of each state,
and pairwise hidden-state transition probability:

P(z_t=i,z_(t+1)=j | y, model) proportional to
alpha_t(i) * T[i,j] * p(y_(t+1)|j) * beta_(t+1)(j).

These quantities are calculated in the log domain and normalized
using log-sum-exp. Expected counts are pooled only across observed
within-segment transitions. Each fish and each gap-separated segment
contributes an initial-state expectation.

The M step adds a **positive** symmetric pseudocount (prior) to each
transition row cell and initial-state cell before normalization.
This protects against zero-count degenerate rows but introduces an
explicit smoothing assumption. Convergence is measured by the
maximum parameter change, not merely a log-likelihood increase.
The method retains an observed-data log-likelihood trace and
convergence flag. With pseudocount regularization, monotonicity of
the *unpenalized* likelihood is not guaranteed.

The state means must be in strictly increasing order. The transition
matrix is K-by-K with rows as source states and columns as next states.
Only these transitions and the initial distribution are fitted;
Gaussian means, Gaussian SDs and K stay fixed.

## Gaps, missing observations and experimental units

The preparation layer refuses to bridge missing observations, invalid
flags, large time gaps, or animal/session/camera/tank boundaries.
Short observations remain unsupported, not silently imputed.
The transition probabilities are **per adjacent recorded sample**:
unequal sampled intervals inside max_gap_s are still not modeled
with a continuous-time transition-rate matrix.

An independently held-out predictive score can be requested with
aqt_hmm_holdout_score(). The function rejects overlapping scoped
fish identities. By default it additionally requires tank_id in
both training and heldout data and refuses any overlapping tank IDs.
This checks sample provenance but cannot prevent all biological
leakage without reliable annotation and data governance.

## Limits of the result

- A model can fit synthetic labels perfectly even if the labels do
  not correspond to real behavioural or physiological states.
- A likelihood improvement is model fit, not evidence of causal
  intervention response or welfare improvement.
- The number of camera frames, fish or tracked samples cannot replace
  the number of independently treated experimental tanks.
- Gaussian fixed-emission misspecification, tracking identity switches,
  3D optical uncertainty and informative missingness can bias transitions.
- Parameters may vary by fish, condition, species or time; the current
  pooled model cannot represent those effects.
- Positive pseudocount regularization does not guarantee identifiable
  state emission interpretations or calibrated posterior coverage.

## Required future validation

Evaluate independent annotated fish behaviour, stability across frame
rates and camera positions, robust longitudinal/tank-level designs,
alternative state counts and emission distributions, multiple optimizer
starts, simulated and real-data parameter recovery, and uncertainty
propagation from source video/identity to state and treatment conclusions.
