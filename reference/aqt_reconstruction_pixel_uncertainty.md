# Attach pixel-noise stereo uncertainty to a reconstructed 3D fish path

This function requires raw 2D view observations, their verified
correspondences already stored in the reconstructed object, and its
original non-refractive camera rig. Returns the same 3D trajectories
with conditional uncertainty columns. Identity and calibration errors
remain excluded.

## Usage

``` r
aqt_reconstruction_pixel_uncertainty(
  reconstructed,
  view_a,
  view_b,
  sigma_px = 1,
  draws = 300L,
  seed = 1001L,
  level = 0.95
)
```

## Arguments

- reconstructed:

  Output of aqt_reconstruct_3d().

- view_a, view_b:

  Original camera-local 2D tracks.

- sigma_px:

  Assumed camera-specific localization SD in pixels.

- draws:

  Number of Monte Carlo replicates.

- seed:

  Seed without changing external R random state.

- level:

  Equal-tail interval central mass.

## Value

3D aqt_tracks with estimated conditional uncertainty fields.
