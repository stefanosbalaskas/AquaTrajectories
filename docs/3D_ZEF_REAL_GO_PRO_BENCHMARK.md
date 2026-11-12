# Wave 11H — 3D-ZeF20: the priority two-GoPro fish stereo benchmark

## Source and why it matters

- Original source / scientific methodology:
  https://github.com/mapeAAU/3D-ZeF
- Camera/setup and original split:
  https://vap.aau.dk/3d-zef/
- Archived benchmark labels and recordings:
  https://motchallenge.net/data/3D-ZeF20
- Dataset mirror:
  https://huggingface.co/datasets/vapaau/3D-ZeF
- Official metrics:
  https://github.com/dendorferpatrick/MOTChallengeEvalKit/tree/master/ZF3D

The original research used **two genuine GoPro cameras**, top cam1 and
front cam2, a glass aquarium, reference corner world-to-camera
correspondences, intrinsic lens calibration, and manually annotated
fish head points, bounding boxes and identities. Eight sequences
separate fish cohorts across training/validation/test. The 0.8MB
benchmark labels ZIP is the first feasible original dataset acquisition
target; videos are about 14GB.

The source repository describes
cam1.mp4, cam2.mp4, cam1_intrinsic.json, cam2_intrinsic.json,
cam1_references.json, cam2_references.json.
Its camera code loads intrinsic JSON keys K and Distortion and each
reference point as {camera:{x,y},world:{x,y,z}}; the source explicitly
states world reference coordinates in **centimeters**.
The original ZF3D evaluator reads source 3D GT rows with fields
frame,id,3d_x,3d_y,3d_z, and its optional semicolon-separated
annotations_full.csv includes cam1/cam2 head-point and box columns.

### Important scientific distinction

3D fish labels, even when annotated consistently, are not necessarily
independently surveyed *true physical XYZ* at every video frame.
The aquarium corner reference points used to fit extrinsics cannot be
reused as independent camera-validation targets. A geometric residual
or 3D tracking MOTA is not underwater absolute positional RMSE.

The code and benchmark datasets may carry **different licenses**.
The original code repo is MIT; MOTChallenge dataset archive states
CC BY-NC-SA 3.0 with potential additional source terms. A Hugging Face
mirror lists MIT in its card; that does NOT automatically override
the benchmark archive's noncommercial source terms. Verify the
license per downloaded artifact before redistributing or training.

## Recommended validation design

1. Inspect the 0.8MB original labels ZIP before downloading video:
   identify native file paths, frame origins, GT columns, camera
   intrinsics, aqua-corner references and camera-specific annotations.
2. For each split, keep all fish from a recording/cohort together.
   Never train, tune or recalibrate on the independent test cohort.
3. Run GoPro PyAV PTS/metadata and fish detector with frozen model
   weights for both camera recordings. Camera 1/2 frame counts and
   physical shutter synchronization must be checked separately.
4. Match detections to manual top/front fish head points and IDs;
   test cross-view correspondence, dropped frames, false positives,
   ID swaps, HOTA/IDF1 and official 3D-ZeF evaluator MOTA.
5. Reconstruct refraction-corrected 3D coordinates with source
   camera K/D/reference calibration. Compare with labelled 3D track
   positions, reporting **agreement with provided 3D labels** only.
6. To certify absolute physical XYZ RMSE, separately acquire an
   independently surveyed underwater checkerboard/bead target
   dataset not used to estimate camera or refraction parameters.
7. Evaluate joint optical + identity + timing sensitivity using
   independent-tank research designs; do not call HMM locomotor
   clusters biological stress or fish welfare reference labels.

## Executable read-only source probe

Use the header-only original 3DZeF20Lables.zip archive:

~~~sh
python inst/python/aqt_3dzef_source_probe.py \
  --labels-zip /data/3DZeF20Lables.zip \
  --out /data/zef_original_label_schema.json
~~~

After verifying original calibration file paths and datasets:

~~~sh
python inst/python/aqt_3dzef_source_probe.py \
  --intrinsic-json /data/ZebraFish-01/cam1_intrinsic.json \
  --references-json /data/ZebraFish-01/cam1_references.json \
  --out /data/zef_camera_calibration_schema.json
~~~

The script checks zip path traversal, archive expansion bounds,
GT row/frame/track identity validity, K/Distortion shapes, four
original camera/world reference corners and input hashes. It refuses
to invent reference truth, fish positions, physical clock alignment
or independently measured underwater XYZ.

A separate GitHub Actions check can acquire this publicly available
small original label ZIP and publish a structural report after the
runner executes. Any download block must remain a disclosed gate,
not a silently substituted synthetic archive.
