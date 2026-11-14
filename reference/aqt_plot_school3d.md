# Show simultaneous observed fish-school positions in physical 3D

Creates an rgl snapshot of actual calibrated XYZ positions for one
camera/session/time. Camera-local track IDs are labels only; positions
are not rendered as anatomical fish meshes. No assumption of a tank
boundary, depth axis orientation, or fish welfare is made.

## Usage

``` r
aqt_plot_school3d(tracks, session_id, camera_id, time_s, label_ids = TRUE)
```

## Arguments

- tracks:

  Calibrated 3D aqt_tracks in tank coordinates.

- session_id, camera_id:

  Identifiers for one sampled group.

- time_s:

  Exact observation time on the synchronized session clock.

- label_ids:

  Whether to show camera/session-local track labels.

## Value

Observed fish positions invisibly; opens an optional rgl scene.
