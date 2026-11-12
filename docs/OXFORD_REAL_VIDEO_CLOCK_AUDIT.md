# Wave 12B — original Oxford fish-video pixel decode and PTS manifest

## Independent source and licence

The original Oxford Detect+Track project by Dutta et al. (2025, Royal
Society Open Science, DOI 10.1098/rsos.242086) publishes real Picasso
triggerfish aquarium videos showing fish navigating randomized obstacles.

- Official project: https://www.robots.ox.ac.uk/~vgg/research/fish/
- Original evaluation videos (15 recordings, ~34 MB):
  https://thor.robots.ox.ac.uk/~vgg/data/fish/fish-tank-obstacles-eval-15.zip
- Original 20-video training ZIP (~45 MB), separate from 419-video test
  ZIP (~992 MB) listed at the project site.
- Stated project-asset license: CC BY-NC 4.0. This CI uploads only derived
  metadata, not original source video bytes or image frames.

Unlike the original 3D-ZeF *label-only* archive inspected in Wave 11H,
this source provides real fish-video pixels for decoding/clock audit.

## Executable video source audit

Run the script with:
    python inst/python/aqt_oxford_video_probe.py
      --archive /data/fish-tank-obstacles-eval-15.zip
      --session-id oxford_eval --camera-id oxford_single_video
      --output-dir /data/oxford_source_audit

The script checks ZIP member safety and original video selection, hashes
the original ZIP and a temporarily extracted source recording, inspects
codec, image dimensions and source stream timebase, uses FFmpeg to decode
one real frame, and exports every decoded video timestamp from FFprobe.

Two derived outputs are created: frames.csv and audit.json.
Frame CSV columns:
session_id,camera_id,frame_id,time_s,width_px,height_px.

Frame IDs are zero-based and time_s is relative to the first *actual*
video-local PTS. Timestamp spacing is **not synthesized from nominal FPS**.
The complete source video, original frame images and source ZIP are not
redistributed by this repository or the CI artifact.

By default the lexicographically first eligible recording is chosen.
Use --member with an exact archive path for another source recording.

## CI acceptance

The dedicated Oxford workflow downloads the original 34 MB evaluation
ZIP, expects the stated 15 video records, verifies an actual decoded
pixel frame and strictly increasing observed PTS, and publishes a derived
frame-clock CSV plus source SHA-256 report. Contract tests run separately;
mocked video decoders alone do not count as authentic real-video execution.

## Explicit scientific limits

- Original video-local presentation timestamps are **not independently
  measured shutter-exposure times or multi-camera hardware sync**.
- This workflow does **not** train or evaluate a fish detector, derive
  ground-truth boxes/IDs, or calculate AP/F1/HOTA/IDF1.
- It does not imply that Oxford annotated videos are a valid reference
  for different tank domains or fish species without validation.
- No underwater absolute XYZ accuracy, calibrated optical uncertainty,
  fish welfare classification or tank-level treatment effect is certified.

For scientific Level-2 qualification see:
https://github.com/stefanosbalaskas/AquaTrajectories/issues/40
and the model+external-label acceptance gate:
https://github.com/stefanosbalaskas/AquaTrajectories/issues/46

Wave 12B is a source-video execution and timing-integration milestone, not
full fish-video tracking measurement validation.

## Additional original-source quantitative comparison

Oxford's published methods state these 454 behavioural recordings were
captured by an **overhead GoPro Hero 5**, at nominal 1080-pixel resolution
and 60 frames per second. Trial segments were later converted to H.264 MP4.
Consequently these genuine **fish GoPro video** clips may no longer carry
the original camera's raw GPMF metadata or physical shutter time. The
AquaTrajectories source probe only claims PTS of the published MP4 clips.

The original project repository also includes:

- Manually reviewed fish LISA annotations: final
  data/annotations/eval/fish/4-all-frames-DONE.json
- Previously generated EfficientDet fish detections:
  data/annotations/eval/fish/2-all-frames-auto-detections.json
- Source commit 0d57a17148f750ed7c327ba5d36ce587d3b7dcfe.
- Source manual/auto Git blob SHA:
  8e2b2a30d87dae2f0624450cf7c8f51c4fbb0760 /
  831418e7780864d1caecb1469b31f3a908e2269d.

A separate Python audit and dedicated GitHub Actions job compare these two
**real source** JSON datasets, retaining 4,462 evaluated frames across 15
recordings including 304 manually empty frames. On the original files,
using maximum-cardinality 0.50-IoU box matching, our reproduced source
comparison produced 4,159 reviewed fish boxes, 1,656 automatic fish
detections, TP=1,654, FP=2 and FN=2,505; pooled precision 99.8792%,
recall 39.7692%, and F1 56.8874%. The CI checks these exact source
denominators, hashes and scientific claim flags before exporting an
evidence JSON artifact.

**Interpretation:** this describes agreement between Oxford's **original
published EfficientDet automatic detections** and the source's final human
reviewed annotations. AquaTrajectories has not yet rerun the original
EfficientDet or a new trained detector on video; the manual annotations
may themselves have been assisted by the original detector and cannot be
declared prediction-blind. High precision combined with low recall
supports studying missed detections, but is not proof of improved
AquaTrajectories tracking or animal welfare measurement. HOTA/IDF1
require actual identities and separate official scoring.

The new source audit is available at
inst/python/aqt_oxford_detection_audit.py and
.github/workflows/oxford-detection-agreement.yml.
