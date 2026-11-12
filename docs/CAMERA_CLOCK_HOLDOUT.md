# Wave 7D — camera clock drift and independent sync-pulse holdouts

## Why time calibration matters for fish trajectories

A pair of geometrically plausible camera rays can come from DIFFERENT
moments in a swimming fish's motion. Frame-rate metadata, a recorded
start time or an internally fitted affine clock relationship alone
does not demonstrate multi-camera synchronization.

AquaTrajectories already contains \`aqt_sync_fit()\` and
\`aqt_sync_apply()\` as simple marker-based affine-clock primitives.
This wave adds explicit **independent heldout physical-event checks**,
session-scoped mappings and source timestamp provenance before
allowing a synchronized trajectory into optical reconstruction.

## New methods

- \`aqt_sync_holdout_fit()\` takes externally identified shared physical
  sync pulses, >=4 training marker IDs and >=2 DISJOINT holdout marker
  IDs, across at least two cameras per session. For each camera and
  recording session it estimates:
  \`reference_time_s = intercept_s + slope * camera_time_s\`.
  The declared reference camera maps to itself. Residual diagnostics
  include the fitted training RMSE, heldout RMSE, largest heldout
  absolute error and inferred drift in parts per million.
  Heldout pulses outside the calibration time range are explicitly
  flagged as extrapolation. Every selected pulse must occur in
  every relevant camera, so silent unmatched-marker deletion is
  forbidden. A researcher-specified tolerance is evaluated, but
  failing sessions remain visible in the output.
- \`aqt_sync_holdout_apply()\` applies only matching session/camera
  transforms to validated \`aqt_tracks\` observations. It defaults
  to refusing failed heldout timing tolerances or extrapolation
  outside the observed pulse support. It preserves original raw
  times, per-observation calibration residual diagnostics, and
  clock-extrapolation distances. A second mapping to tracks
  already containing \`time_raw_s\` is rejected.

## Example: known shared LED/TTL pulse markers

~~~r
library(aquaTrajectories)

# pulse_log: independently verified common physical pulse events
# and camera-local timestamps, with session_id/camera_id/marker_id/time_s
fit <- aqt_sync_holdout_fit(
  pulse_log,reference_camera="CAM_TOP",
  train_markers=paste0("flash_",1:8),
  holdout_markers=paste0("flash_",9:12),
  max_holdout_error_s=.005
)
print(fit$fits)
print(fit$holdout)

# Converts camera-local 2D tracks into a common CAM_TOP time base,
# preserving time_raw_s and recording every heldout timing diagnostic.
same_clock <- aqt_sync_holdout_apply(
  pixel_tracks,fit,
  require_tolerance=TRUE,max_extrapolation_s=0
)
~~~

## Scientific boundaries

- The same \`marker_id\` in two files does NOT verify the same
  physical pulse was captured. Hardware/LED/TTL acquisition and
  annotation must be independently inspected.
- The model is affine in time: one offset and one constant drift
  slope per camera/session. It is NOT an estimate of jitter,
  dropped frames, rolling shutter or nonlinear clock drift.
- The reference camera defines the time origin; it is not necessarily
  a calibrated GPS/UTC or physiological event clock.
- Heldout clock residuals and prespecified tolerance are empirical
  checks against the selected pulse source, not scientific proof
  of global synchronization during every fish frame.
- Holding out physically later pulses is often an extrapolation
  test. This does not replace tests throughout the video recording.
- Frame exposure midpoints, progressive sensor rolling shutters,
  water-optical reconstruction and cross-view fish identity require
  additional independent calibration.
- Any camera time conversion may shift exact pixel detections to
  nonidentical floating-point seconds; fish correspondences must
  still be explicitly reviewed and bounded by physical clock skew.
- If an experiment log has a different clock from the reference
  camera, separately register event times to the reference
  clock before interpreting fish trajectories as event responses.

## Benchmark priorities

Document real camera hardware synchronization pulses with externally
surveyed event times, quantify maximum residual clock offset/drift
across long sessions, and inject realistic jitter/dropouts into
known-movement trajectory reconstructions. Evaluate how timing errors
propagate into physical 3D RMSE and feeding response estimates.
