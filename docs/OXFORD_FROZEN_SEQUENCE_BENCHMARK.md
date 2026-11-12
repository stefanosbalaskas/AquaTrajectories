# Wave 13E — full genuine fish-video detection + tracking, with scored source annotations

## Objective

For the first time in AquaTrajectories, run the **original frozen Oxford
fish-trained EfficientDet-D2 model** directly on **all 149 decoded frames**
of the original published fish video, preserve source MP4 presentation
timestamps, generate model outputs, run a real ByteTrack tracker on
those outputs, then compare **newly inferred model boxes** with the
source's final reviewed fish annotations.

This integrates Wave 12B source pixels/PTS and reviewed labels with
Wave 13B actual frozen model execution and Wave 13A actual ByteTrack.
The model is the original Oxford model, not a newly trained
AquaTrajectories model.

## Input selection — never use arbitrary internet checkpoint

Original Oxford Detect+Track, Dutta et al., Royal Society Open Science
(2025): https://github.com/ox-vgg/fish-tank-obstacles

- Repository/source commit:
  `0d57a17148f750ed7c327ba5d36ce587d3b7dcfe`
- Frozen original fish EfficientDet-D2 v2 SavedModel checked against
  three original Git blob hashes, using TensorFlow CPU 2.16.2.
- Original evaluation archive ZIP SHA-256:
  `91c71d297b7bfa6bd19c6f34ec5d12e1534bf7ef2f90d3249662605507ca9ae4`
- Original first video `eval/F30_T15.mp4`, SHA-256:
  `acd118909b7bd44b013450e35525409ab2bfe53e15e81f48834fe33bfea682c0`
- 149 actual MP4 frames, H.264 1920×1080 at released 25 fps,
  video-local presentation span 0–5.92 s.
- Original reviewed final LISA annotation Git blob
  `8e2b2a30d87dae2f0624450cf7c8f51c4fbb0760`.
- Source and model license stated CC BY-NC 4.0; only derived
  measurement artifacts are uploaded, not original video or weights.

## Exact pipeline

1. Verify original ZIP, video and fish checkpoint file hashes.
2. Decode all video PTS using FFprobe, and all frames using FFmpeg
   with synchronization disabled (`-vsync 0`). Verify one-to-one
   frame count, source filename and clock correspondence.
3. Load original TensorFlow SavedModel once; infer each source frame
   with an explicitly recorded input dtype/geometry transformation.
   No prediction oracle, labels or tuneable test thresholds are used
   as model inputs.
4. Parse the **verified original Oxford `detect-efficientdet.py`
   source tensor convention**: [batch_index,ymin,xmin,ymax,xmax,
   confidence,class_index]. Enforce finite confidence and pixel
   geometry, count invalid above-threshold boxes separately rather
   than silently clipping them away.
5. Compare all frame predictions with original final LISA boxes
   using maximum-cardinality 2D box matching at predefined
   IoU 0.50 and model score thresholds 0.50/0.70.
   Include reviewed zero-fish frames, count TP/FP/FN and print
   precision/recall/F1 by threshold. Do not optimize thresholds on
   this evaluation recording after observing the labels.
6. Run actual `supervision==0.26.1` ByteTrack on newly inferred
   model detections (minimum initial confidence 0.25). Preserve
   recording-local fish identities, generated 2D boxes and actual
   frame PTS, report assigned tracks and observation gaps.
7. Export model-generated detections, associated tracks and a
   SHA-256 / model source / source clock / quantitative result
   report. GitHub Actions publishes derived artifacts only.

## Boundaries

This is a **real executed detector + tracker benchmark on one published
recording**, but the source's final manual fish annotations may have
been influenced by model-generated proposals, so we must not call
this prediction-blind external accuracy certification.

The source does not independently label multiple fish identities.
The tracked fish IDs are an algorithm's hypotheses; official
HOTA/IDF1, biologically true IDs, cross-view correspondence, camera
exposure synchronization and physical underwater XYZ remain untested.

A full Level-2 benchmark still needs independently labelled held-out
multi-fish recordings across tanks/species, third-party annotation
review with model predictions hidden, and exact official TrackEval
execution. Separate physical underwater target metrology and tank-level
behavioural/ACI experiments remain required.

Research gates: https://github.com/stefanosbalaskas/AquaTrajectories/issues/51
