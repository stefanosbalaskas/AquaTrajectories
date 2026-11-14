# Propagate assumed camera pixel localization noise into stereo XYZ

This draws independent Gaussian X/Y errors for each image observation
(one scale per camera), then triangulates using fixed calibrated pinhole
projection matrices and \*fixed known correspondences\*. Derived
intervals are sensitivity intervals CONDITIONAL on the assumed pixel
error model, rig and identity assignments, not validated confidence
intervals.

## Usage

``` r
aqt_stereo_pixel_mc(
  xy1,
  xy2,
  P1,
  P2,
  sigma_px = 1,
  draws = 300L,
  seed = 1001L,
  level = 0.95
)
```

## Arguments

- xy1, xy2:

  Corresponding n-by-2 image-coordinate matrices.

- P1, P2:

  Calibrated non-refractive 3-by-4 projection matrices.

- sigma_px:

  Pixel SD as a single nonnegative number or length-two camera-specific
  vector. Zero gives an exact deterministic baseline.

- draws:

  Number of Monte Carlo replicates, at least 20.

- seed:

  Random seed; does not modify global RNG state.

- level:

  Central fraction for equal-tailed Monte Carlo intervals.

## Value

Per-point estimate, XYZ standard deviations, covariance terms,
equal-tail intervals, valid replicates and validity fraction.
