# Fit a tank/fish nested longitudinal model using established nlme

Fits a simple Gaussian linear mixed-effects model with treatment, epoch
and their interaction as fixed effects plus nested random intercepts for
independent tanks and fish within tank. This is not automatic causal
identification, nor does it model heteroscedasticity, autocorrelation,
calibration errors or identity uncertainty. Report
singularity/convergence, treatment replication and residual diagnostics.

## Usage

``` r
aqt_hierarchical_event_fit(prepared, method = c("REML", "ML"))
```

## Arguments

- prepared:

  Data from aqt_hierarchical_event_prepare().

- method:

  "REML" (default) or "ML".

## Value

List containing native nlme fit and a design audit.
