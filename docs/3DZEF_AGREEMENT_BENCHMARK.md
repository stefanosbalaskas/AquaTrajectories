# Wave 12A — 3D-ZeF original-label agreement and evaluation gates

## What this milestone closes

Executable source-labelled **published-label comparison** for original 3D-ZeF:
from original 5-column GT (or the source ZIP) to separately produced 3D
predictions, fully declared evaluated-frame scope, per-frame FP/FN counts,
Euclidean 3D agreement in **source centimetres**, IDF1-like association,
adjacent identity switches, and SHA-256 audit artifacts.

The accompanying GitHub Actions workflow acquires **actual original** fish GT
records and verifies the known source structure. Its regression test data are
constructed examples, not proof of fish model accuracy. If no independently
produced model predictions and frame review are supplied, **no real fish
prediction accuracy is calculated**, even though original labels are inspected.

This is a narrower engineering milestone toward Level 2 and **does not close**
the overall [scientific validation gate](../issues/40) or certify real underwater
XYZ, absolute camera synchronization, HOTA, or fish welfare inference.

## Source constraints

- Original labels: https://motchallenge.net/data/3DZeF20Lables.zip
- Original source and calibration: https://github.com/mapeAAU/3D-ZeF
- Dataset: https://vap.aau.dk/3d-zef/
- Original ZF3D official evaluator:
  https://github.com/dendorferpatrick/MOTChallengeEvalKit/tree/master/ZF3D
- License: confirm the source archive's **CC BY-NC-SA 3.0 and any supplemental
  terms** before use/redistribution. The CI only publishes a derived count/hash
  report; it does not rehost source fish annotations or videos.

The script consumes only fields \`frame,id,3d_x,3d_y,3d_z\`; the original source
may contain more columns. Both source frames and fish IDs are 1-based positive
integers. The physical 3D source unit is centimetres. These are published
tracking *labels* derived in the source measurement workflow, **not
independently surveyed physical fish XYZ ground truth**.

## Audit the genuine original annotation ZIP

~~~bash
python inst/python/aqt_3dzef_agreement.py \
  --labels-zip /data/3DZeF20Lables.zip \
  --audit-json /data/3dzef_audit.json
~~~

The resulting report names every real GT member and summarizes its fish
observations, source frame range, IDs and ZIP SHA-256, while explicitly marking
that **no predictions have been scored**. Four training GT sequence files and
27,026 observations were observed in the previously verified source artifact.
The CI enforces these as expected source-schema invariants. Changes upstream
should be investigated, not silently accepted as benchmark improvements.

## Compare genuinely independent 3D predictions

First, inspect the audit for the exact member path of the intended **training**
sequence. No test annotations should be invented or requested from hidden GT.
Create your own \`prediction.txt\` containing one row per predicted fish point:

~~~text
1,7,19.61,28.313,7.93
2,7,19.68,28.34,7.88
~~~

These are illustrative format rows, **not model predictions**.

Create \`evaluated_frames.csv\` from a prediction-blind fully annotated
frame review. Include all reviewed frames, **even those with zero fish**:

~~~csv
frame,review_status,reviewer_id
1,fully_annotated,reviewer_A
2,fully_annotated,reviewer_A
3,fully_annotated,reviewer_A
~~~

Then run:

~~~bash
python inst/python/aqt_3dzef_agreement.py \
  --labels-zip /data/3DZeF20Lables.zip \
  --archive-member "EXACT_GT_MEMBER_FROM_AUDIT" \
  --predictions /data/prediction.txt \
  --evaluated-frames /data/evaluated_frames.csv \
  --frame-count VIDEO_FRAME_COUNT_FROM_REAL_VIDEO \
  --threshold-cm 2.0 \
  --output-dir /data/zef_agreement
~~~

\`--frame-count\` must come from an externally checked complete video/sequence
manifest; do not infer it from the last occupied GT row. The cutoff is an
**explicit analysis choice**, in centimetres, not automatically a validated
physical tolerance. Sensitivity analysis should repeat the scorer with
prespecified plausible cutoffs and report the entire curve.

Outputs: \`summary.json\`, \`per_frame.csv\` and \`matches.csv\`.
All score inputs and output CSVs are SHA-256 recorded. Existing nonempty
output directories are refused. Source GT copied verbatim to predictions is
rejected as oracle/leakage scoring. Predictions beyond reviewed frames are
excluded from scores, with excluded counts disclosed.

## Metric meaning

Framewise one-to-one 3D Euclidean associations maximise the number of pairs
within the selected distance threshold, then minimise error using exact
bipartite assignment. Out-of-threshold points remain false positives / false
negatives. Unmatched predictions on explicitly declared zero-fish frames
count as false positives; unreviewed frames do **not** become zero-fish frames.

The score reports:

- Position RMSE and MAE in cm among **matched source-label points only**,
  with matched-sample denominator and omissions shown separately.
- Axis-wise coordinate bias and RMSE in cm; no interpretation of these as
  independent physical metrology.
- Match precision/recall and explicit detection failures, evaluation-frame
  fraction, and total original rows omitted outside the reviewed frame scope.
- An internally computed IDF1-like global identity assignment, allowing
  arbitrary predicted ID permutations but penalising broken tracks;
  adjacent-frame ID changes are diagnostic and not official CLEAR MOT.
- Null/undefined values for metrics whose denominators are zero, instead of
  fabricating perfect scores.

**Do not report these ID metrics as official ZF3D MOTA, MOTChallenge IDF1 or
TrackEval HOTA.** For any publication benchmark, run and archive the original
ZF3D evaluator or an independently checked TrackEval-compatible implementation,
including its exact commit, matching thresholds, preprocessing, and all
unmatched detections. An official 2D HOTA benchmark additionally requires
camera-specific independent 2D annotations and predictions.

## Remaining acceptance gates

1. Acquire real original videos, verify both camera frame timelines and
   hardware exposure synchronization separately.
2. Train/obtain a **fish-specific** detector and tracker, freeze weights,
   training cohorts, inference configuration and output hashes.
3. Produce genuine held-out 3D predictions with independently reviewed
   2D/3D fish annotations and full evaluated-frame coverage.
4. Run independent official tracking metrics; investigate shadows, occlusion,
   wrong species and cross-camera identity swaps.
5. Survey physical underwater XYZ targets **not used for calibration**;
   estimate absolute 3D bias/RMSE and uncertainty coverage by tank and depth.
6. Carry observation failures and identity uncertainty into preregistered
   fish/tank-level behavioural inference without pseudoreplication.

Passing package tests or authentic-label format audits does **not** satisfy
these scientific validation gates.
