# Construct coherent measurement-error scenarios for 2D/3D fish trajectories

Draws conditional additive position errors in the \*same units as
tracks\*. Each track's residual error is an AR(1) process across
consecutive valid observed samples, with a second, constant per-track
offset for an optional correlated systematic component. AR(1) is indexed
by observations, not by a physical continuous-time correlation model.
Invalid/missing samples and segments longer than max_gap_s reset the AR
process. Fish identity is FIXED.

## Usage

``` r
aqt_trajectory_ensemble(
  tracks,
  sigma = 0.1,
  rho = 0,
  systematic_sd = 0,
  draws = 200L,
  seed = 31L,
  max_gap_s = Inf
)
```

## Arguments

- tracks:

  Validated aqt_tracks, 2D or 3D.

- sigma:

  Independent innovation marginal SD per coordinate axis.

- rho:

  Correlation parameter for AR(1), strictly between -1 and 1.

- systematic_sd:

  Constant position offset SD per scoped track and axis.

- draws:

  Number of conditional scenarios, \>= 20.

- seed:

  Reproducible integer seed, preserving caller RNG.

- max_gap_s:

  Largest adjacent observation interval for AR continuation.

## Value

An aqt_trajectory_ensemble with base tracks, draws, and assumptions.

## Details

This is a researcher-defined sensitivity model, not a calibrated error
model or a replacement for source video/annotation validation. The
return stores all simulated paths but does not change the original
observations.
