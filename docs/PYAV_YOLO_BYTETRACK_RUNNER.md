# Wave 11B — optional PyAV / YOLO + ByteTrack video runner

This optional Python workflow decodes each video frame *once* using PyAV,
reading the same decoded frame's PTS and BGR image for YOLO+ByteTrack.
It avoids mismatches between two separate video decoders and does not
replace real fish training or independent evaluation.

## Execute with fish-specific weights

```sh
python -m pip install av ultralytics
python -m pip freeze > fish_runner_requirements.lock.txt
python inst/python/aqt_track_video.py \
  --video /path/to/GoPro.mp4 \
  --weights /path/to/fish_model.pt \
  --output-dir /path/to/output \
  --prefix tank1_top \
  --session-id tank1 \
  --camera-id TOP \
  --confidence 0.25
```

This runner is optional: the R package does not automatically install
PyAV, Ultralytics, PyTorch or trained fish-specific model weights.

## Outputs and R import

The script emits four files:

- `tank1_top.frames.csv`: every decoded frame, zero-based ID, local
  PTS seconds, image size, including frames with zero detections.
- `tank1_top.mot.txt`: headerless MOTChallenge 10-column per-track
  records, 1-based frame ID, track ID, XYWH pixels, confidence and
  three -1 placeholder columns.
- `tank1_top.classes.csv`: class ID for each tracked-box row, in the
  same order as MOT export; no automatic fish species validation.
- `tank1_top.run.json`: video/model SHA-256, exact runtime version,
  local PTS origin and config, tracked/unassigned counts and explicit
  scientific non-certification.

```r
library(aquaTrajectories)
frames <- aqt_frame_manifest(
  read.csv("/path/to/output/tank1_top.frames.csv"))
labels <- read.csv("/path/to/output/tank1_top.classes.csv")
tracks <- aqt_import_mot(
  "/path/to/output/tank1_top.mot.txt",
  frames,session_id="tank1",camera_id="TOP",
  frame_origin=1L,class_ids=as.character(labels$class_id))
audit <- aqt_mot_support_audit(tracks,frames)
```

## Limitations and validation gate

Real fish inference has NOT been run or evaluated by the CI tests.
The Python workflow validates its self-contained conversion logic
using dependency-free unit tests, not a real GPU/video/Ultralytics stack.
The supplied weights require fish-specific training, independent labels
and reporting of precision/recall, IDF1 and external HOTA metrics.
Unassigned detections are counted but never assigned fabricated IDs.
Camera PTS is not a common synchronized exposure clock. Individual
fish are never assumed matched across camera views. Two-view 3D
reconstruction still needs underwater physical calibration targets
and independently reviewed correspondences.

Publishing this runner as a validated end-to-end fish system requires
real GoPro integration runs with the same software versions, measured
reference XYZ, external fish annotations, perturbation/occlusion
benchmarks and independent experimental tanks.
