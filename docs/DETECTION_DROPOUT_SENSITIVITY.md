# Wave 13D — correlated fish-detection misses propagated into behaviour

This branch advances priorities **5 and 6** as a conditional sensitivity
implementation, without incorrectly declaring externally calibrated
measurement uncertainty or biologically validated treatment inference.

## Scientific reason

Fish detection recall is not perfect. Missing observations lead to missing
speed segments, biased path lengths and unreliable event epochs.
Existing AquaTrajectories geometry/identity sensitivity capabilities do
not by themselves encode temporally correlated detector loss. The new
native R exports retain full source timestamps and missing fish rows
rather than interpolating missing trajectories:

- `aqt_detection_dropout_scenarios()` models assumed, fish-specific
  Markov detection loss, including burst persistence over consecutive
  frames, with reproducible draws, accurate original-row denominators,
  preserved session/camera/track identity, and explicit stochastic
  assumptions. An existing missing fish row stays missing.
- `aqt_detection_event_sensitivity()` recalculates kinematics and
  event epochs within each conditional source-measurement scenario.
  It never multiplies the number of independent treated tanks by the
  number of fish, frames or simulation draws.

## Statistical formulation

Let p be the assumed stationary missing-detection probability and rho
the autocorrelation/persistence parameter. The Bernoulli dropout state
transition probabilities are:

- Missing after previously missing: p + rho * (1-p).
- Missing after previously observed: p * (1-rho).

For p=0 no additional observations are dropped. When rho approaches
one, lost observations cluster in bursts. The process is a **conditional
sensitivity model**, not a validated detector observation model.

**Source-data grounding:** Oxford's published high-confidence
EfficientDet file was previously compared with 4,157 comparable
human-reviewed fish boxes over 4,461 frames, with source-model recall
39.7883% at 0.5 IoU (after excluding the ambiguous frame).
This is **not a calibrated independent AquaTrajectories detection
failure probability**, and that point estimate must not be used as
an automatic default for other models, fish or tanks.

## Run

    scenario <- aqt_detection_dropout_scenarios(
      tracks, p_missing = 0.2, persistence = 0.7,
      draws = 100L, seed = 42L)
    epoch <- aqt_detection_event_sensitivity(
      scenario, external_events, outcome = "speed")

The p=0.2/rho=0.7 above are explicit *illustrative assumptions* only.
No physical accuracy or causal treatment validity is implied.

## Qualification and next gates

- R CMD check includes synthetic known-truth no-dropout tests, stochastic
  reproducibility tests, exact timestamp preservation, original
  unobserved fish rows, numeric argument guards, and event-epoch
  response invariance when p=0.
- Need real fish detector error probabilities by species/tank/frame and
  expert-reviewed occlusion labels before calibrating p and rho.
- Need physical timestamp/calibration/identity uncertainty combined
  with detection loss (rather than parallel independent scenarios)
  and measured interval coverage on holdout tanks/targets.
- Need treatment randomization, independent replicated tanks, expert
  biological reference labels and prespecified GLMM/HMM/functional
  evaluation before any welfare or intervention claim.
- The generic statistical output is not a full measurement error
  posterior, a validated 95% confidence interval, or biological truth.

Umbrella scientific acceptance:
https://github.com/stefanosbalaskas/AquaTrajectories/issues/51

## Combined physical stereo validation protocol (priorities 3 + 4)

Wave 13D also adds the native R export
`aqt_multiview_holdout_protocol()`, composing the preexisting
`aqt_sync_holdout_fit()`, `aqt_target_trial_table()` and
`aqt_target_holdout_benchmark()` into one strict experiment-level
qualification. It requires physically corresponding **training and
heldout pulse IDs** as well as separately measured target assemblies
and paired undistorted 2D image coordinates. Every physical trial must
name camera/session scopes covered by the timing holdout.

The output retains all holdout clock residuals, physical target errors,
failed 3D reconstruction denominators and unit labels. A passing
**software protocol** only verifies the supplied data contracts and
mathematics; it cannot authenticate the external survey, hardware
exposure pulses or independent calibration collection. Therefore all
physical certification flags remain false pending genuine tank
measurements and independent review.

Synthetic known-geometry R tests use precisely surveyed virtual XYZ
as a **software reference** and two simulated camera pulse clocks, never
claiming those inputs came from real aquarium hardware.

**Qualification note:** This protocol composes existing audited functions; the caller is responsible for collecting actual optical/hardware evidence. CI validates only software and synthetic known-truth fixtures.
