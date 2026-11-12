# Wave 13B — first frozen fish-trained inference execution gate

This wave addresses the first runnable part of the **priority 1**
(real fish detection) validation requirement, using Oxford's original
fish-trained EfficientDet-D2 SavedModel on an actual source fish-video
frame. This is *not yet* a full-video detection-accuracy benchmark.

The source is Oxford Detect+Track / Dutta et al. (2025), Royal Society
Open Science, original project https://www.robots.ox.ac.uk/~vgg/research/fish/ .
Source code, annotations, trained weights, and video are stated as
CC BY-NC 4.0. Original repository:
https://github.com/ox-vgg/fish-tank-obstacles , exact commit
`0d57a17148f750ed7c327ba5d36ce587d3b7dcfe`.

## Original fish-model source identity

The script enforces **all three original exact Git blob hashes**:
- `saved_model.pb`: `a1bcfd8e2344a2e2680017bdf7e7bacd0a5bcd6f`
- `variables/variables.index`: `420b256e96b2d2ce468b6a705659123df18184bb`
- `variables/variables.data-00000-of-00001`:
  `804884ec04b8b5c4ead2030b650ecc074e8fd735`

The CI downloads the original Oxford fifteen-video evaluation ZIP,
validates source/clip SHA-256 against Wave 12B, decodes one original
`eval/F30_T15.mp4` frame as a JPEG and loads the frozen original TF
SavedModel with `tensorflow-cpu==2.16.2` on Python 3.11.

The model serving signature is **inspected at runtime** before inference.
Only supported input data types and shapes are accepted. Any spatial
resizing, dtype casting or conversion is recorded; missing output data,
nonfinite outputs and unknown source weights **fail the qualification**.
The output audit contains only model/file hashes, actual signature,
tensor metadata and execution-provenance flags, not original licensed
video pixels or pretrained model weights.

## Run locally

    python -m pip install tensorflow-cpu==2.16.2 Pillow
    python inst/python/aqt_oxford_frozen_model_smoke.py \
      --model-dir /data/Oxford_saved_model \
      --frame-jpeg /data/real_decoded_fish_frame.jpg \
      --out /data/model_smoke_audit.json

## Scientific interpretation

Passing the CI will establish that an **original frozen fish-trained
model was actually executed on an original fish-video frame** using
a fully recorded input transform and model-source hash. It does not
show that predicted boxes align with reviewed source annotations,
that the model generalizes to new tanks or species, that the Oxford
final labels were prediction-blind, or that fish identities are
correct. The exact output tensor schemas and score calibration must
first be checked before computing detection AP/F1 on all held-out
frames.

Continue the same workstream by:
1. Decode all frames and preserve all MP4 PTS (Wave 12B source).
2. Parse model output coordinates/scores with explicitly confirmed
   original model semantics, freezing NMS, preprocessing and threshold.
3. Compare **newly inferred** outputs against a prediction-blind
   reviewed recording holdout, including zero-fish frames.
4. Run qualified ByteTrack and a second tracker on the genuine detector
   outputs, and benchmark against independently labelled **multi-fish
   identity trajectories** with official TrackEval HOTA/AssA/DetA/IDF1.

Follow-on independent optical calibration, surveyed XYZ, joint
uncertainty, behavioural intervention inference, researcher explorer
and ACI remain separate priorities. Their scientific acceptance
requires external measurement data; a model smoke run does not
certify them.

Open tracking accuracy gate:
https://github.com/stefanosbalaskas/AquaTrajectories/issues/46
