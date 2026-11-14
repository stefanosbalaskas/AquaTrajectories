# Fit camera clock offsets and drifts with independent sync-marker holdouts

Fits affine mappings from camera time to one externally declared
reference camera using \>=4 training pulses and \>=2 disjoint physical
holdout pulses per session and camera. Unlike a simple two-point
offset/drift fit, it reports heldout residuals, offset and drift,
extrapolation risk and failure of a prespecified maximum clock error.
Markers must be physically corresponding events: matching text IDs alone
do not certify synchronization.

## Usage

``` r
aqt_sync_holdout_fit(
  markers,
  reference_camera,
  train_markers,
  holdout_markers,
  max_holdout_error_s = 0.005
)
```

## Arguments

- markers:

  Frame with session_id,camera_id,marker_id,time_s; all identifiers
  complete and every selected pulse in every camera.

- reference_camera:

  Name of reference camera.

- train_markers, holdout_markers:

  Disjoint unique character IDs of physical sync events, at least four
  and two respectively.

- max_holdout_error_s:

  Externally declared maximum absolute synchronization residual in
  seconds, strictly positive.

## Value

aqt_clock_holdout containing session/camera affine fits, individual
heldout residuals and failed-tolerance flags.
