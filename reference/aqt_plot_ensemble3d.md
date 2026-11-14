# Plot conditional 3D fish trajectory ensembles using optional rgl

Draws 3D reference and simulated paths for one scoped fish. Requires
complete, actual XYZ coordinates and an installed rgl package.

## Usage

``` r
aqt_plot_ensemble3d(ensemble, session_id, camera_id, track_id, n_draws = 10L)
```

## Arguments

- ensemble:

  An aqt_trajectory_ensemble containing 3D tracks.

- session_id, camera_id, track_id:

  Full scoped fish identity.

- n_draws:

  Number of 3D scenario lines (maximum 30).

## Value

Invisible selected observation indices; creates rgl scene.
