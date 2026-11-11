# AquaTrajectories: event-aligned, tank-replicated statistical analysis

## Wave 4A delivered methods

- aqt_event_epoch_summary() reduces time-stamped movement measurements
  into named time windows before/after each actual recorded event.
  Window boundaries are in seconds relative to event onset.
- aqt_design_audit() checks the number of unique independent tanks in
  each between-tank treatment group and disallows treatment switching
  within the same tank for this analysis type.
- aqt_tank_event_contrast() estimates the difference in within-tank
  pre/post changes between two treatment groups. Its nonparametric
  percentile interval resamples entire tanks independently within
  treatment groups, never frames or individual fish.
- aqt_plot_tank_changes() displays one paired line per independent tank,
  separately for the two treatment groups.

## Demonstration with four independent tanks

~~~r
library(aquaTrajectories)
epochs <- data.frame(
  tank_id=rep(c("C1","C2","T1","T2"),each=2),
  treatment=rep(c("control","control","treatment","treatment"),each=2),
  epoch=rep(c("baseline","response"),4),
  value=c(5,6,5,7,5,8,5,9)
)

aqt_design_audit(epochs)
fit <- aqt_tank_event_contrast(epochs,draws=1000,seed=7)
print(fit$estimate)
print(c(fit$lower,fit$upper))
aqt_plot_tank_changes(fit)
~~~

This demonstration has exactly two tanks in each group, which is a
minimal code fixture rather than a recommended statistical sample size.

## What is required of actual fish-tracking experiments

1. The tank is normally the experimental unit for a treatment applied
   to that tank. Multiple fish, video frames, repeated sessions or
   overlapping windows are not additional independently treated tanks.
2. Intervention timing and actual exposure must be recorded, not inferred
   from computer-vision trajectories alone.
3. Outcome definitions should be frozen before analysis if the objective
   is confirmatory causal inference.
4. Each tank needs finite baseline and response estimates, and between-
   tank treatment assignment must remain constant in this simple design.
5. Treatment and comparison tanks must be independently replicated.
   Crossover, split-plot, network interference, time-varying treatment,
   cluster randomization and repeated independent events require more
   advanced study-specific statistical designs.
6. The simple implementation equally weights valid fish/session summary
   rows when constructing each tank-by-epoch mean; sample availability
   and weighting choices must be reported.
7. A time-weighted epoch mean is a trapezoid average across contiguous
   finite observations, with a max_gap_s threshold when supplied.
   Missing or non-observed measurements interrupt the estimator.
8. The tank-resampling percentile bootstrap does not automatically
   correct treatment confounding, heterogeneity, strong temporal
   dependence, informative missingness, calibration error, or
   cross-tank dependence.
9. Intervals from this bootstrap are empirical cluster-resampling
   sensitivity summaries. Adequate interval coverage needs evaluation,
   particularly with very few independent tanks.
10. A before/after treatment-group difference does not prove a causal
    treatment effect without an appropriate identification strategy.

## Intended next inference milestone

- Richer experimental-unit schemas, sample-size simulations,
  hierarchical repeated measures, residual dependence diagnostics.
- Model-based GLMM/GAMM and Bayesian backends with explicitly qualified
  assumptions and correct unit handling.
- Measurement-error and camera-identity uncertainty carried through
  event metrics and treatment contrasts.
- Known-truth coverage, small-sample calibration and comparison with
  established R statistical tools.
