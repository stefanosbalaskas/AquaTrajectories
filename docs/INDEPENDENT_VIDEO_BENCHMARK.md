# Wave 11D — independent fish-video benchmark and full Python–R data handoff

## Status and claim boundary

This module is an **executable reproducibility and input-integrity gate**
for the real-video workflow. It does not create independent expert
annotations, train a detector, qualify a GoPro, verify physical clock
synchronization, establish true 3D accuracy or diagnose fish welfare.

The four exported files are read together and cross-checked. The
Python-to-R test uses a **mocked decoder and tracker**, expressly not
a real fish video. Successful CI verifies the software interface only.

## Export verification

The optional PyAV runner in \`inst/python/aqt_track_video.py\` now emits
video bundle schema 1.1:

- \`PREFIX.frames.csv\`: every decoded frame, exact relative video PTS,
  scoped camera/session, measured image dimensions
- \`PREFIX.mot.txt\`: tracked 2D fish boxes and confidence, possibly
  **zero bytes** for a valid video with no tracked fish
- \`PREFIX.classes.csv\`: exact (zero-based frame, numeric track ID,
  numeric class) sidecar for each MOT observation
- \`PREFIX.run.json\`: manifest recording matching output names,
  schema, original source hashes, runtime configuration, row counts
  and SHA-256 of each of the other three files

The video runner refuses existing output names for the prefix and
fails if a tracker changes its class within a camera-local ID.
\`aqt_video_bundle_import(directory,prefix)\` rejects:
wrong names/versions, missing files, digest mismatches, class keys
misaligned with MOT file row order, declared/actual counts diverging,
noncontiguous decoded frame indices, wrong clock origin, invalid
camera/session scope, duplicate tracker observations and invalid boxes.

**The output hashes are NOT signed.** They detect accidental corruption
and file mixing, but cannot authenticate the identity of the researcher
or verify independently collected video. Original input video/model
file SHA-256 is recorded but not rechecked by the R importer; keep
those files, compare their digests and archive the fitted model.

The runner uses PyAV frame PTS, not nominal FPS. These values are
*camera-local* and do not prove common shutter exposure timing.

## Evaluation with independently annotated frames

An annotated dataset needs three explicit comma-separated files:

1. \`video_evaluated_frames_template.csv\`: the exact video frames
   completely annotated by human reviewers **including empty frames**.
2. \`video_reference_boxes_template.csv\`: true fish bounding boxes
   in the same raw, unrectified camera pixel coordinate system and
   numerical class coding as the model export.
3. \`video_reference_tracks_template.csv\`: stable within-camera
   manually reviewed individual identities, per-annotated-frame centre
   points, and class IDs. An annotation does NOT imply permanent identity
   across different cameras.

Headers for all three are provided under \`inst/extdata\`, intentionally
**without invented ground-truth rows**.

Example in R:

~~~r
library(aquaTrajectories)
bundle <- aqt_video_bundle_import(
  directory="/path/to/verified_run",prefix="tank1_top")
evaluation <- aqt_video_bundle_benchmark(
  bundle=bundle,
  truth_boxes=read.csv("/path/to/independent_boxes.csv"),
  truth_tracks=read.csv("/path/to/independent_tracks.csv"),
  evaluated_frames=read.csv("/path/to/fully_annotated_frames.csv"),
  max_position_error_px=15,
  iou_threshold=.5,
  confidence_threshold=.25)
print(evaluation$detection)
print(evaluation$tracking)
print(evaluation$annotated_frame_fraction)
~~~

The detection results derive from \`aqt_detection_metrics()\`; tracking
results derive from \`aqt_tracking_metrics()\`. Camera-local IDF1 here
follows the package's explicitly documented association convention and
is **not** a standalone externally certified TrackEval/HOTA score.

Frame coverage is reported as n_evaluated_frames/n_video_frames. When
only a sampled subset was independently annotated, predictions in all
other frames must not be scored as false positives. False positives on
genuinely empty **fully annotated** frames must still count. Species
coding must match the detector output; an apparent identity metric
on wrong-class labels is not a valid detector benchmark.

## Independent evaluation design required for publication

- Keep training, model selection and final test videos separate by
  physical recording, fish group/tank and acquisition session.
- Annotate a prespecified, representative sample: shadows, occlusions,
  overlapping fish, reflections, different sizes, mixed species and
  challenging tank depths. Include video frames genuinely empty of fish.
- Store frame and animal annotations together with reviewer IDs,
  disagreement adjudication and raw video hashes.
- Report detection precision, recall and AP by species and video
  condition; include false positive and false negative counts.
- Report identity continuity and errors, IDF1, ID switches and
  **external TrackEval HOTA** computed with compatible benchmarks.
- Compare independently surveyed underwater XYZ target reconstructions
  under actual GoPro optical settings and measured camera hardware
  synchronization. Record invalid reconstructions in denominators.
- Preserve independent experimental tank replication in behavioural and
  causal comparisons; frames and fish are not treatment replicates.

## Cross-language CI

\`.github/workflows/video-bundle-roundtrip.yml\` generates version 1.1
bundles through the actual Python runner while **mocking PyAV and YOLO**.
It then installs AquaTrajectories and uses R to import these exact
bytes, verify SHA-256, preserve irregular timestamps, score a known
synthetic reference case, and accept an empty-track video.

The tests verify interoperability. They cannot substitute for real
GoPro acquisition, fish-trained YOLO weights, independent human truth,
tank sampling or external measurement and uncertainty calibration.
