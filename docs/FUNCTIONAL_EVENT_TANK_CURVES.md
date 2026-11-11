# Wave 8B — gap-safe event-aligned functional fish trajectories

## Motivation

Fish/video time series are not independent experiments at the frame
level. A valid analysis can construct aligned curves of swimming speed
(or X/Y/Z positions) around feeding and other interventions, but must
retain missingness and respect the independently replicated tank.

Wave 8B implements a **finite-grid descriptive analysis** of such
curves. It does NOT claim a functional mixed model, sparse FPCA,
independently certified physiological response, or calibration of
underwater optical/identity uncertainty.

## New public methods

- \`aqt_functional_event_grid()\`: aligns each independently scoped
  observed fish outcome series to researcher-specified event-relative
  REAL seconds, rather than normalizing duration to 0..1.
  Intermediate values are interpolated only between adjacent
  observed finite source samples whose separation does not exceed
  \`max_gap_s\`. It NEVER interpolates across intervention onset, even
  when both adjacent samples are observed. Missing source frames
  and long gaps remain explicitly missing. Every included session
  requires an externally recorded event (one per session).
- \`aqt_functional_coverage()\`: provides time-specific visible fish
  fractions and recording-session coverage, so uncertain support
  near interventions is never silently hidden in a mean curve.
- \`aqt_functional_tank_contrast()\`: first averages fish within each
  independent tank at each available time, then computes a curve of
  between-treatment differences across replicated tanks. It
  resamples entire tanks WITHIN treatment, not frames or fish.
  Pointwise percentiles and an empirical maximum-absolute-deviation
  simultaneous band are returned. These are DESCRIPTIVE cluster
  resampling bands, not proven frequency-calibrated CIs.

## Illustration

~~~r
library(aquaTrajectories)
# tracked: validated 2D/3D fish trajectories
# kinematic: numeric speed derived from finite clock-aware segments
kinematic <- aqt_kinematics(tracked,max_gap_s=.2)
# Requires tank_id, treatment, and one event per session.
curves <- aqt_functional_event_grid(
  kinematic,events,outcome="speed",
  grid_s=seq(-5,5,by=.25),max_gap_s=.2
)
print(aqt_functional_coverage(curves))
fit <- aqt_functional_tank_contrast(
  curves,treatment_levels=c("control","treatment"),
  min_fish_fraction=1,draws=999,seed=21
)
print(fit$curve)
print(fit$design_audit)
~~~

Here tank/treatment metadata must be present on the original tracked
data and remain constant for the whole observation per fish.

## Limitations

- Only ONE intervention per session and one session/event per tank
  for the tank-contrast estimator. Repeated events, crossover designs
  and longitudinal correlated interventions require another model.
- \`speed\` derived by finite differencing starts with an undefined
  initial speed and can have missing values around occlusions.
  The grid retains unsupported observations as NA. Users may
  choose an explicitly justified minimum supported fish fraction.
- Changes in fish coverage around events can bias mean curves;
  \`min_fish_fraction=1\` is the strict default.
- Even complete, gap-safe trajectories may be biased because
  underwater glass optics, fish-identity switches or imperfect
  timestamp synchronization were not corrected. This wave
  does not combine these measurement scenarios with the
  independent-tank resampling bands.
- The resampling band is not independently coverage-validated.
  For few tanks, discrete bootstrap estimates can be misleading.
  A replicated tank design and a predeclared inferential model
  are required for treatment-effect claims.
- The method uses per-tank mean fish outcomes, not fish-level
  random slopes or nonlinear continuous-time mixed models.
- Frame sampling times cannot become randomized experimental units;
  zero or missing tank-level replication raises an error.

## Validation priority

Benchmarks should introduce known intervention-locked trajectories
alongside missing frames, camera drift, identity switches, and
tank-correlated random effects. Test curve bias, support,
simultaneous-band coverage and false discovery under the null
before claiming calibrated treatment uncertainty.
