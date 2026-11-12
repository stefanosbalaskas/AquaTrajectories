# Wave 8C — longitudinal functional event curves with nested fish/tank AR(1)

## Why this module exists

The earlier \`aqt_functional_tank_contrast()\` gives each experimentally
independent tank equal weight in a time-specific descriptive
between-treatment curve and performs resampling at the correct
tank cluster level. That addresses pseudoreplication, but does not
provide a parametric within-fish temporal correlation model.

This wave exposes a deliberately NARROW established R backend
for repeated within-fish curves:

- \`aqt_functional_longitudinal_prepare()\` requires complete, equally
  spaced event-relative curves, exactly one intervention per tank,
  two declared between-tank treatments, >=3 independently assigned
  tanks per arm and >=2 fish per tank. It rejects missingness,
  duplicates, inconsistent times, treatment switching, and
  multiple experiments per tank. This is a strict statistical
  subset, not a general missing-data framework.
- \`aqt_functional_longitudinal_fit()\` uses \`nlme::lme\` with
  Gaussian treatment by natural cubic spline(time) fixed effects;
  independent tank and fish-within-tank random intercepts; and
  an OPTIONAL \`nlme::corAR1\` within-fish residual process.
  Natural spline bases are provided by R's recommended
  \`splines\` package.

The model does **not** call any unqualified EyeTrajectories native R
backend. It is NOT sparse FPCA, a nonlinear state HMM, Bayesian
animal welfare inference or an automatically identified causal
treatment effect.

## Example

~~~r
library(aquaTrajectories)

# From prior validated 2D/3D fish trajectories with tank_id/treatment:
kin <- aqt_kinematics(tracks,max_gap_s=.2)
curves <- aqt_functional_event_grid(
  kin,events,outcome="speed",
  grid_s=seq(-5,5,by=.2),max_gap_s=.2
)
# Requires fully finite observations for every fish/time,
# >=3 independent tanks per arm and >=2 fish per tank.
prepared <- aqt_functional_longitudinal_prepare(
  curves,treatment_levels=c("control","treatment")
)
# Optional recommended nlme package, generally supplied with R.
fit <- aqt_functional_longitudinal_fit(
  prepared,spline_df=3,residual="ar1",method="REML"
)
summary(fit$model)
fit$design_audit
fit$fixed_effects
~~~

## Scientific considerations

1. Requiring complete event curves avoids silent imputation, but
   can SELECT a nonrepresentative set of fish/recordings when
   occlusion depends on movement, treatment or camera geometry.
   The number of missing/excluded observations must be reported.
2. Within-fish residual AR(1) is an explicit model of correlation
   between equally spaced time GRID measurements. It is not
   assumed to measure true mechanical or physiological memory.
3. Random intercepts distinguish independently treated tanks
   and repeated fish but do NOT include random slopes by fish/tank,
   species effects, spatial interference, or separate tank AR(1).
4. Spline fixed effects describe mean time profiles. The treatment
   by time interaction can represent differential time evolution,
   but such coefficients cannot establish causality without a
   defensible experimental assignment design.
5. REML and ML optimize different likelihood targets. Nested model
   comparison requires explicit scientific/statistical justification.
6. No camera/clock/fish-ID uncertainty is included in the fitted
   residual distribution. External measurement-sensitivity
   scenarios must be analyzed separately.
7. Every fish frame is NOT an independent experimental replicate.
   At least three tanks per treatment is a software precondition,
   not a power or asymptotic validity guarantee.
8. Wald tests from \`nlme\` must be interpreted cautiously when
   sample size is limited by the number of independent tanks.
9. This method is NOT independently calibrated against real
   aquaculture outcomes. Numerical regression checks test the
   implementation contract on known simulated structure only.

## Future research

- Complete-case selection and informative occlusion sensitivity.
- Irregular continuous-time within-fish residual correlation.
- Nested random slopes and functional random effects.
- Joint measurement/experimental uncertainty with known 3D
  camera calibration and identity switch probability models.
- Cross-validation and Type I error simulations under actual
  tank replication and temporal dependence.
- Comparison with \`mgcv\`, \`glmmTMB\`, and qualified functional
  mixed-model methods for non-Gaussian, nonlinear or nonstationary
  outcomes.

Scientific benchmarks and external validation must be archived
with the full data/code provenance before a publishable accuracy claim.
