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
