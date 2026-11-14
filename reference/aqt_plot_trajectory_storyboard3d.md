# Publication-style four-panel 3D fish trajectory storyboard

Produces a static 2 x 2 axonometric projection of a single observed
physical-XYZ fish track. Earlier contiguous movement is grey; two
non-overlapping recent windows are light and dark blue. The same
physical tank bounds and view are used for all four panels.

## Usage

``` r
aqt_plot_trajectory_storyboard3d(
  tracks,
  times_s = NULL,
  session_id = NULL,
  camera_id = NULL,
  track_id = NULL,
  recent_s = 2,
  max_gap_s = Inf,
  max_age_s = 0.2,
  tank_limits = NULL
)
```

## Arguments

- tracks:

  Validated 3D aqt_tracks in physical tank units (cm or m).

- times_s:

  Four strictly increasing timestamps. NULL uses four equally spaced
  times across the observed trajectory duration.

- session_id, camera_id, track_id:

  Optional identifiers selecting one fish scope. Required if input
  contains multiple scopes.

- recent_s:

  Width (seconds) of each of the two recency bands.

- max_gap_s:

  Largest allowed consecutive observed sampling interval; Inf permits
  any gap without an explicit missing row.

- max_age_s:

  Largest allowed age of the last observed position for showing the
  current fish head and reporting its latest speed.

- tank_limits:

  Optional list(x=c(min,max),y=c(min,max),z=c(min,max)) in the same
  physical units as tracks. Without it, visible bounds are inferred from
  supplied observed XYZ, not independently measured.

## Value

Invisibly, a four-row data frame with audited per-frame observed
distance, latest valid speed, current-observation status, and counts.
Draws a four-panel static figure on the active base graphics device.

## Details

Segments spanning explicitly missing fish observations or a time gap
larger than max_gap_s are not connected or counted in distance. No depth
is inferred from 2D pixels. The distance is the sum of observed valid
segments, NOT an estimate of unobserved travel. Speed is measured over
the most recent valid observed segment, not a smoothed or instantaneous
biological velocity. Supplied physical coordinates and any external
calibration require separate validation.
