# Wave 11A — camera-local video PTS and MOTChallenge/ByteTrack integration

## Objective and boundary

The package accepts independently generated object-tracker exports and
timebases without confusing tracker frame indices with physical exposure
times. A nominal FPS is **not** adequate when the video has dropped frames,
variable frame-rate presentation timestamps or reordered recording segments.

This wave does **not** execute inference in Ultralytics YOLO, ByteTrack,
idtracker.ai, OpenCV or ffmpeg. It reads externally exported MOTChallenge
files (or data frames) and externally verified video-frame manifests.
Neither an import passing R tests nor tracker confidence = 1 identifies
the correct individual fish biologically.

## Required per-video frame manifest

Provide a row for **every acquired frame, including those containing zero
detected fish**, with:

- `session_id` and `camera_id` uniquely identifying a video recording;
- zero-based `frame_id` integer (may have gaps when source acquisition
  did not deliver a frame);
- measured video `time_s` on that camera's local clock (e.g. PTS);
- positive integer `width_px`, `height_px`.

The manifest rejects duplicate frame IDs, out-of-order/non-increasing PTS,
incomplete camera/session identifiers, impossible image sizes and
resolution changes inside a recording. Video PTS does not establish
synchronized capture across multiple GoPros. Use separately qualified
synchronization pulses and a common reference time for cross-view work.

## Native R example

~~~r
library(aquaTrajectories)

frames <- aqt_frame_manifest(data.frame(
  session_id="experiment_1",camera_id="gopro_top",
  frame_id=c(0,1,3,4),time_s=c(0,.041,.152,.195),
  width_px=1920,height_px=1080))
# A valid headerless MOT file has positional columns:
# frame_number, track_id, xmin, ymin, width, height, confidence,...
# MOT convention generally numbers its first frame as 1.
tracks <- aqt_import_mot(
  "external_tracker_results.txt",frames,
  session_id="experiment_1",camera_id="gopro_top",
  frame_origin=1L)
aqt_tracks_validate(tracks)
support <- aqt_mot_support_audit(tracks,frames)
print(support)
~~~

For multi-species recordings, pass a per-observation `class_ids`
vector sourced from independent species labels or an explicitly
identified external classifier. The importer rejects a species
change within one camera-local track without human review.

## Dataset provenance and failure safety

- MOT bounding boxes are `left, top, width, height`, in full-resolution
  unrectified pixels matching `width_px` and `height_px`.
- Only predictions with confidence in [0,1] and numeric nonnegative
  track IDs are accepted. MOT detection-only ID = -1 is rejected.
- `frame_origin` defines which MOT frame number maps to frame_id = 0.
- Every MOT frame must appear in the declared frame manifest.
- XY coordinates are box centres, not segmentation masks or fish heads;
  this makes position accuracy conditional on the detector export.
- No fish is invented on a missed frame. No gap is interpolated.
- Source frame numbers, bounding boxes, detector confidence and species
  classes are retained for diagnostics.
- Different cameras can reuse the same tracker ID; their identities
  remain camera- and session-scoped until reviewed cross-view matching.
- The explicit external timestamps remain camera-local. Hardware
  exposure timing, shutter phase and clock drift are separate.
- `aqt_mot_support_audit()` counts missing detections only among
  acquired manifest frames **between** first and last observations.
  It cannot infer an animal's true presence on those empty frames.

## Remaining end-to-end work

1. Standalone, version-pinned Python CLI to execute YOLO+ByteTrack and
   export canonical MOT files and verified frame/PTS manifests.
2. Independent fish detector training and annotation, mixed species
   label performance, shadows/reflections and occlusion tests.
3. External HOTA/IDF1 tool comparison and full track failure QC.
4. Video calibration including real GoPro intrinsics and underwater
   refractive target metrology, plus synchronized multiple camera clocks.
5. Uncertainty propagation from detection and correspondence to
   3D movement and independently replicated tank treatment conclusions.

Without measured real data and external labels, no end-to-end tracking
accuracy or biological interpretation is certified.
