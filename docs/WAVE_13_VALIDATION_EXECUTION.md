# Wave 13A — real Oxford fish detections executed through ByteTrack

This milestone is a real **tracking-algorithm execution**, not an independent
identity-accuracy certification. It addresses the first runnable part of
priority 2, while priority 1 (frozen model inference) remains open.

## Source, procedure, reproducibility

- Original Oxford Detect+Track fish trials and published EfficientDet detections:
  https://github.com/ox-vgg/fish-tank-obstacles, commit
  `0d57a17148f750ed7c327ba5d36ce587d3b7dcfe`.
- Input is the original
  `data/annotations/eval/fish/2-all-frames-auto-detections.json`,
  with source Git blob `831418e7780864d1caecb1469b31f3a908e2269d`.
- There are 4,462 source annotation frames, 15 separate recordings,
  and 1,656 already-published fish detector observations, including
  genuine zero-detection frames. Original confidence scores are preserved.
- Runtime `supervision==0.26.1` offers an actual ByteTrack implementation.
  Trackers are reset at each original recording; class IDs are NOT species.
- Box association uses the actual original detector coordinates and scores.
  No source video is decoded by this step, no PTS is synthesized, and
  official identity metrics are not computed because the external reviewed
  reference data lacks independently verified multi-fish identity tracks.
- Output contains one row per assigned fish box with recording-scoped
  track ID, original source frame number, 2D box, score and source metadata.
  A SHA-256 source/provenance report accompanies the CSV, with per-recording
  tracker counts and observed gaps. Session-scoped IDs must never be
  interpreted as the same biological fish between different recordings.

Run:

    python -m pip install supervision==0.26.1 numpy
    python inst/python/aqt_oxford_real_bytetrack.py \
      --detections /data/oxford-original-auto.json \
      --output-dir /data/oxford_real_tracker

The exact-head CI acquires the original source annotation JSON, validates
its Git blob hash, executes pinned ByteTrack over all 15 genuine recording
sequences, and exports **derived tracking rows and audit JSON only**.

## Boundary of the scientific claims

An actual tracker run is now feasible on real source detections. These
are **not newly inferred** detections from AquaTrajectories, and the 0.7+
Oxford detection selection leaves out lower confidence fish observations.
Thus two-stage ByteTrack low-confidence recovery cannot be assessed on
this source. The final Oxford reviewed labels may have been informed by
the original detector. Report no official HOTA/IDF1, MOTA, cross-camera
identity accuracy, fish welfare, or physical underwater 3D validation.

Next steps for priority 1+2:
1. Run a verified, frozen fish-trained EfficientDet or YOLO model on the
   original camera video pixels; preserve the hash of weights, per-frame
   confidence/NMS and original clock.
2. Compare **model-generated**, not reused original published outputs
   against prediction-blind externally reviewed fish box labels on full
   heldout sessions.
3. For multi-fish videos with real independent identity GT, invoke the
   official TrackEval reference implementation to obtain HOTA/DetA/AssA
   and IDF1, plus switches and fragmentation.
4. Compare actual ByteTrack to BoT-SORT/ReID on high density, occlusion,
   reflections and other species; retain all individual fish/tank units.

## Combined nine-priority gate

The real tracker output is now a data input for planned multiview,
calibration, joint uncertainty, biological inference, 3D explorer and ACI.
Do **not** mark those experimentally validated until the original
two-view exposure clocks and surveyed underwater targets, replicated
tanks, events and independent welfare labels are available.

Tracking validation issue:
https://github.com/stefanosbalaskas/AquaTrajectories/issues/46
