# Visualize conditional position-error trajectories alongside observed fish

Shows a small set of simulated path scenarios together with original x/y
coordinates. These are hypothetical error-model trajectories, not
observed alternative fish paths or calibrated statistical envelopes.

## Usage

``` r
aqt_plot_ensemble2d(ensemble, session_id, camera_id, track_id, n_draws = 20L)
```

## Arguments

- ensemble:

  An aqt_trajectory_ensemble.

- session_id, camera_id, track_id:

  Full scoped fish identity.

- n_draws:

  Number of scenario trajectories to display (1 to 60).

## Value

Base R plot, invisible selected row indices.
