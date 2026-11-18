# Priority B — genuine model-tracking error propagation into *observable* fish motion

This stage evaluates **real detector and tracker estimates on original
Fraunhofer HHI ricefish A JPEG frames**. It uses the source's published
tracking labels and the *existing already qualified* frozen Oxford
EfficientDet-D2 model predictions, actual ByteTrack, and a Hungarian
association alternative. **No idtracker.ai, SLEAP or fine-tuned YOLO runs
are included in this source-specific empirical test.**

## Source and reproducibility

- Original HHI Video A MOT/JPEG ZIP SHA-256
  `18c39619b1f84ea774f16fedfac5911d92de86ab7da4aa03cf365b9b4be58ceb`.
- Original source GT file SHA-256
  `b70a699b4e41cbec636e5f4b500482451d40ddad29fb387dc36dc0c6392021d3`.
- Original JPEG frame IDs 43,450–43,550, remapped explicitly to local
  1–101 after source verification; every original JPEG is required.
- Original 9,214 GT fish observations, 260 source fish identities.
  Published source fish identity labels may have been model-assisted and
  have **not** been independently prediction-blind adjudicated.
- Original model inference and output files are obtained only from
  exact [Wave 14G successful run 43372413985](https://github.com/stefanosbalaskas/AquaTrajectories/actions/runs/43372413985),
  and original frozen script verifies the SHA of both derived CSVs.
- Both trackers consume the same newly inferred fish detections, *not*
  source GT boxes or identities. Source IDs enter evaluation only.
- Source HTTPS chain is incomplete, so downloaded bytes are SHA-verified
  against previously recorded source hashes but download peer identity
  is not independently authenticated.

## What is evaluated

The source fully enumerates **101 original still images**, but the ZIP
does **not** provide authenticated camera presentation/exposure timestamps.
Therefore this study cannot estimate speed in cm/s or even trustworthy
pixels/second. The valid time coordinate is the consecutive original
source frame *index*. Zero durations and missing acquisition intervals
are never imputed.

A prespecified 0.50 IoU gate and maximum-cardinality Hungarian assignment
pair model-generated body boxes to source GT body boxes in each source
frame. GT fish IDs are not passed to either model or tracker.

For ByteTrack and the alternative association separately, report:

1. Original GT fish count, model-prediction count, IoU≥0.5 matched
   observation count and fraction of *all* GT fish positions supported.
2. Original source GT adjacent-frame fish motion intervals, supported
   adjacent intervals with both boxes matched to the **same predicted ID**,
   detected-but-switched intervals, and unsupported intervals. Denominator
   identity is strictly checked.
3. True vs predicted **2D bounding-box-centre displacement** over
   *only the same supported adjacent source-frame intervals*, expressed in
   pixels per adjacent frame index. Long gaps, missing frames and changed
   predicted IDs are not bridged.
4. Conditional-on-supported-pairs source/predicted path length in pixels,
   absolute instantaneous frame-to-frame *displacement* error in pixels,
   and common-support path-length bias. These conditional summaries do
   not generalize to the many missed detections.
5. Observed contemporaneous matched-pair fish-to-fish pixel separation
   error. This is an image geometry summary, not externally calibrated
   nearest-neighbor/social-behaviour validity or tank physical schooling.
6. Missed-detection/reacquisition fragmentation and ID changes among
   contiguous successful matches. Gaps in the reference annotation
   itself do not count as tracker failures.

**Denominator-first interpretation:** report the observed support fraction
before a low conditional error mean. When the detector misses almost all
fish, the tiny subset of matched trajectories can give misleadingly small
error conditional on detection. That is selection, not model reliability.
No tank-replicated biological intervention or fish welfare outcomes are
available; no stress/feeding or causal claim is made.

## Run

The new reproducible workflow is
`.github/workflows/priority-b-real-trajectory-error.yml`.

For an externally provided source archive and frozen Wave 14G derived CSV
files with their original report:

```sh
python inst/python/aqt_real_fraunhofer_behaviour_error.py \
  --source-archive /sources/mot_a.zip \
  --model-csv /verified/fish_model_detections.csv \
  --bytetrack-csv /verified/fish_model_bytetrack.csv \
  --model-report /verified/report.json \
  --out /new-evidence/real_fish_source_frame_behaviour_error.json
```

The runner refuses altered original source/derived CSV hashes, duplicate
identities in a source frame, source-frame range mismatch, missing
evidence data, and overwriting an earlier report. It does not modify
the original ZIP, model weights, videos, annotations or any manuscript.
GitHub Actions downloads original data temporarily but uploads **only
derived error evidence** and the frozen source run ID.

## Qualification levels

- **Software known-answer tests:** synthetic perfect, missing, ID
  switch, reacquisition and unannotated GT-gap cases.
- **Real source evidence:** actual original HHI fish annotations and
  genuine model-generated ByteTrack/alternate tracker positions, with
  exact hash provenance, if the real CI step completes successfully.
- **Not certified:** independent blinded fish identities, true
  biological behaviour, physical motion units and camera PTS,
  multi-tank generalizability, or 3-way idtracker.ai/SLEAP/YOLO
  real-data comparative accuracy.

This extends the existing source-specific error analysis without
making the main Priority B three-model experiment appear completed.
See `docs/PRIORITY_B_CONTROLLED_BENCHMARK.md` in PR #90 and issues
#46 and #51 for remaining independently collected source measurements.
