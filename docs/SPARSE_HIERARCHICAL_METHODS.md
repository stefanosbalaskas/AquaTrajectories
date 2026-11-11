# Wave 6C: sparse functional data and tank-nested longitudinal models

## Goal

AquaTrajectories has independently implemented dense-grid multivariate
trajectory PCA. A separate pathway is required for genuinely SPARSE fish
observation histories with occlusions, irregular timestamps and differing
observation schedules. Sparse FPCA also must not treat hundreds of fish
sharing a tank as hundreds of independently randomized treatment units.

## Methods

1. aqt_sparse_fpca_input(): constructs observed-only ragged Ly/Lt lists
   from the fish coordinate of interest, scoped by camera/session/track ID.
   It does not smooth or interpolate unobserved fish positions.
   Relative time normalization is optional and destroys absolute duration
   information; retain the original duration as an independent covariate.
2. aqt_sparse_fpca_design_audit(): identifies temporal coverage across
   the ensemble, including poorly observed regions. The joint covariance
   surface of a sparse FPCA requires adequate support; this is only a
   marginal per-bin coverage diagnostic, not a complete 2D covariance
   support proof.
3. aqt_sparse_fpca_fit(): optional fdapace::FPCA adapter with forced
   sparse-data mode. fdapace, not EyeTrajectories, supplies the validated
   estimation machinery. Its version and options are retained.
4. aqt_hierarchical_event_prepare(): validates a simple between-tank
   two-treatment, two-epoch experiment with every fish observed in both
   epochs, explicitly nesting fish IDs within tanks and requiring
   independent tank replication.
5. aqt_hierarchical_event_fit(): optional nlme Gaussian mixed-effects
   model with fixed treatment x epoch effects and nested random intercepts
   for tanks and fish within tanks.

## Example for incomplete fish paths

~~~r
library(aquaTrajectories)

# tr: validated canonical trajectories from manual or automatic tracking,
# including explicitly missing/unobserved fish positions.
ragged <- aqt_sparse_fpca_input(
  tr,coordinate="x",time_axis="relative",min_points=3
)
print(aqt_sparse_fpca_design_audit(ragged,bins=10))

# Optional independently maintained backend:
# install.packages("fdapace")
fitted <- aqt_sparse_fpca_fit(ragged)
summary(fitted$fit)
~~~

## Example for tank-level longitudinal treatment contrasts

~~~r
# epochs is a previously verified analysis table, with:
# tank_id, treatment, camera_id, track_id, epoch and value.
prepared <- aqt_hierarchical_event_prepare(
  epochs,treatment_levels=c("control","treatment"),
  epoch_levels=c("baseline","response")
)
# Optional recommended R package:
# install.packages("nlme")
model <- aqt_hierarchical_event_fit(prepared,method="REML")
summary(model$model)
model$design_audit
~~~

The mixed model's interaction coefficient is an associational
difference in epoch change conditional on the model's assumptions;
a causal effect additionally requires a defensible assignment/
identification design.

## Boundaries

- These methods do not estimate a unified XYZ sparse FPCA. fdapace
  accepts one coordinate series per call; multivariate covariance and
  cross-axis constraints need a separately validated method.
- Time-registration onto [0,1] can remove biologically important
  absolute speed/duration information.
- Sparse FPCA estimates require sufficient time design coverage;
  snippets, nonrandom occlusion and highly biased missingness can
  invalidate the estimated mean and covariance.
- Repeated independent experiments with many events, crossover
  treatments, and temporal residual autocorrelation are NOT handled
  by the simple two-epoch nested-intercept model.
- At least two independent tanks per treatment are required as a
  software guard, not a statistically sufficient sample-size guarantee.
- The model does not correct optical calibration errors, probabilistic
  ID switches, missing data mechanisms or unequal observation quality.
- Equal weighting across fish and epochs may not be justified for
  every aquaculture design.
- No EyeTrajectories native R function is called. Integration requires
  source-contract audit, frozen-oracle comparisons, numerical tolerance
  tests and independent certification before enabling any adapter.

## Method references

- fdapace: https://cran.r-project.org/package=fdapace
  Native PACE for sparse and dense functional observations.
- nlme: https://cran.r-project.org/package=nlme
  Nested linear mixed-effects models.
