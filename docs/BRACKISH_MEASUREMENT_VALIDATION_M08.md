# Milestone 08 — Independent image-space measurement validation

## Research scope and source evidence

**Date:** 20 November 2026. Evaluation of *real* five-sequence BrackishMOT test footage via the frozen published fish annotation labels and the previously inferred NMFS-OSI YOLO11n + ByteTrack tracks. Model outputs were not generated using ground-truth boxes; the published annotations are accessed only during scoring. The original 868-frame reference set was previously frozen, the M07 research-input source hashes are checked, and the original track data remain unchanged. No fish detector is trained or altered in this milestone.

**Critical hierarchy:** Published reference identity labels are an external-source reference but **not newly human-adjudicated, prediction-blind biological truth**. Measurement error here is *conditional agreement with those annotations*, **not independently certified biological, physical, or welfare accuracy**. M07's 90/90 R/Python numerical parity was a software-validation result; M08 now assesses *external observation agreement* and observation-selection effects.

## Protocol, denominators and association

1. Verify exact M07 source schema, SHA-256 digests and separate frame/identity scopes. Reject supplied timestamps, source drift, duplicate camera-local identities, invalid box centers and physically unsupported claims.
2. Match each reference fish box to at most one actual model-generated **track** box in the same sequence, camera, and acquisition frame. Use maximum-cardinality, then maximum-IoU Hungarian matching; primary bbox IoU threshold **0.50**. Matching is evaluation-only: the tracker never sees GT during inference.
3. Preserve a full ledger of all 6,621 published reference observations and all 2,830 real model-tracked observations. Record unmatched rows. This is *tracker-output reference agreement*, **not standalone YOLO detection AP or recall**.
4. For each original adjacent-frame **reference fish-ID step**, retain a row even when neither endpoint has a model match. Measure error only when both endpoints match the **same** model-local ID. A mismatch or different model-ID at successive endpoints blocks a paired displacement; never silently join fragments.
5. For school geometry, compare model versus reference on the **same matched subset**, then separately compare matched reference subset against the **full published reference school** to expose missing-fish selection bias. The matched-subset estimates do not represent the whole school.
6. Run sensitivity analyses at IoU 0.30 and 0.70 in addition to the fixed primary 0.50. Sensitivity results are diagnostic, not replacements for the primary headline.
7. An independently coded sparse maximum-bipartite-matching oracle validates the cardinality of every frame-level evaluation assignment and recomputes every matched IoU, center error, original reference step, same-ID pairing and supported matched-group geometry. R separately recomputes source-linked measurement arithmetic from the input and one-to-one matching ledger. GitHub CI tests use **synthetic fixtures only**; the real GT and model prediction rows are never uploaded to the repository.

## Real-data empirical findings

The previously frozen inputs contain 868 source frames. At IoU 0.50, **374 / 6,621 (5.65%)** original published reference fish positions matched a real tracked box; 2,456 / 2,830 model tracks did not match a publisher fish box. These frame-level associations do not measure biological ID correctness.

Across the **6,498** original consecutive-reference-ID steps, only **265 (4.08%)** had matches at both endpoints to the **same** model-local identity. Another **one** pair had both endpoints matched to different model IDs and was excluded from the conditional step-error analysis. The other **6,232** reference steps lacked one or both matched endpoints. Every reference step remains in the audit ledger.

The median image-center position error among **374 matched** positions was **11.90 px**, with 90th percentile **32.84 px**. Among the **265 selected** identity-continuous paired steps, the mean absolute step-length error was **6.48 px per adjacent recorded frame**. Neither estimate describes the errors among all 6,621 source fish observations; selection is substantial, and a low conditional MAE can coexist with bad total track coverage.

At the primary threshold, only **85** source frames have two or more matched reference fish, allowing within-matched-subset radius-of-gyration checks. This is inadequate to certify whole-school geometry. Sequence 23 has **zero** source fish matched in the track output, so its conditional position and step errors are **undefined**, not zero.

Diagnostic sensitivity:

| Evaluation IoU | Matched fish-reference positions | Original adjacent reference steps with same model ID |
| ---: | ---: | ---: |
| 0.30 | 534 / 6,621 (8.07%) | 394 / 6,498 (6.06%) |
| 0.50 | 374 / 6,621 (5.65%) | 265 / 6,498 (4.08%) |
| 0.70 | 172 / 6,621 (2.60%) | 101 / 6,498 (1.55%) |

**Scientific conclusion:** The tested external fish detector/tracker does not supply sufficiently accurate and continuous real fish observations to support general fish-level behavioral trajectory measurement. AquaTrajectories' mathematical operators remain usable on sufficiently reliable externally supplied trajectories, subject to their own assumptions. Numeric package correctness is **not** empirical accuracy of the upstream model.

## Boundary-clipped original-reference sensitivity

The original M06 source audit preserved the original MOT text and recorded **six
partially out-of-image fish boxes** in sequence 55 (original left x = -2 px).
Only their derived evaluation geometry was clipped to x = 0; each retained
more than 98% of its original area. These six reference fish positions were
**not** matched by the model at IoU 0.50, and all **eight** original adjacent
reference steps touching them were already marked missing-model-endpoint.

A separate read-only `aqt_m08_source_clip_sensitivity.py` gate checked the
exact six source records and their original M06 anomaly audit SHA-256. With
those source rows excluded solely for sensitivity accounting (not from the
frozen primary dataset), the matched-reference fraction changes from
**374/6,621 = 5.6487%** to **374/6,615 = 5.6538%**, and eligible-paired-step
coverage from **265/6,498 = 4.0782%** to **265/6,490 = 4.0832%**.
The 374 matched-center errors and 265 paired-step errors are unchanged.
No source observations were overwritten.

To repeat when the original M06 freeze folder is available, run:

```powershell
& $py inst/python/aqt_m08_source_clip_sensitivity.py --input $src --result $out --m06-anomalies "$env:USERPROFILE\Documents\AquaTrajectories_M06_BRACKISH_FROZEN_TEST_V2\SOURCE_ANNOTATION_ANOMALIES.csv" --out "$env:USERPROFILE\Documents\M08_M06_SOURCE_CLIP_SENSITIVITY.json"
```

## Independent audit status

The independent audit passed **374/374** source-based IoU/position checks, **6,498/6,498** original adjacent-step checks and **85/85** supported group-radius checks. It performed **2,133** sparse maximum-cardinality checks (at declared IoU thresholds where both source paths have observations) and confirmed the published ledgers and all report file hashes.

This is independent **software/reference-based audit**, not independent reannotation of biological fish identity. Neither the R package nor the Python evaluation claim independent camera-image labeling, training/test cohort disjointness, independent physical 3D targets or event/experimental validity.

## Scientific gates that remain blocked

| Scientific property | Minimum independent evidence required | Available in the original M07/M08 files? |
| --- | --- | --- |
| Biological fish identity validity | Prediction-blind human-verified fish IDs, quality adjudication and identity-error records | No |
| Physical 2D velocity | Original measured camera exposure/PTS or externally authenticated frame-clock data, with trustworthy units | No |
| 3D swimming distance and stereo accuracy | Independently surveyed underwater XYZ targets, synchronized multi-camera source videos, calibrated intrinsic/extrinsic and refraction model, full observed residuals | No |
| Feeding or stress response | Independently timestamped stimulus/feeding or welfare criterion and synchronized behavior sensor timeline | No |
| Treatment effects | Verified tank assignment and sufficient independently replicated tanks per group | No |

**Interpretation:** the *computational/reference-conditional image-space portion* of Milestone 08 is completed; the *independent biological and physical reference validation* is honestly **BLOCKED_PENDING_EXTERNAL_DATA**, not fabricated or claimed as complete.

## Commands

From the repository root, with original M07 source evidence retained externally:

```powershell
$py = "$env:USERPROFILE\Documents\AQT_M06_FISH_ENV\Scripts\python.exe"
$src = "$env:USERPROFILE\Documents\AquaTrajectories_M07_REAL_INPUT"
$out = "$env:USERPROFILE\Documents\AquaTrajectories_M08_REFERENCE_MEASUREMENT"
& $py inst/python/aqt_m08_reference_measurement.py --input $src --out $out
& $py inst/python/aqt_m08_independent_oracle.py --input $src --result $out --out "$env:USERPROFILE\Documents\AquaTrajectories_M08_INDEPENDENT_AUDIT.json"
```

The independent R measurement validation requires an installed checkout of the feature/release containing the M08 API and then:

```r
library(aquaTrajectories)
root <- "~/Documents/AquaTrajectories_M07_REAL_INPUT"
report <- "~/Documents/AquaTrajectories_M08_REFERENCE_MEASUREMENT"
frames <- read.csv(file.path(root,"M07_FRAMES.csv"),stringsAsFactors=FALSE)
obs <- read.csv(file.path(root,"M07_OBSERVATIONS.csv"),stringsAsFactors=FALSE)
matches <- read.csv(file.path(report,"tables/M08_MATCHED_OBSERVATIONS.csv"),stringsAsFactors=FALSE)
study <- aqt_reference_measurement_validate(frames,obs,matches,iou_threshold=.5)
aqt_reference_measurement_publish(study,"~/Documents/AquaTrajectories_M08_NATIVE_R_AUDIT")
```

This last local R replay is not automatically certified by the Linux CI's synthetic fixtures. The user must compare the reported full-denominator sequence summaries against the independently archived Python values before declaring real R/Python M08 parity.


## Post-merge real-source native R replay (20 November 2026)

The original investigator subsequently installed AquaTrajectories on Windows R 4.6.1
and executed `scripts/m08_real_reference_parity.R` on the original five
BrackishMOT real-data paths. The execution log reported:

```text
M08_REAL_NATIVE_R_PYTHON_PARITY_PASS 65 comparisons 5 sequences
M08 FINAL REAL-DATA R/PYTHON VALIDATION: PASS
Comparisons: 65
```

The R source report's five exported artifacts were independently SHA-256 verified
against `M08_R_OUTPUT_MANIFEST.json`. The reference step ledger independently
reconciled 6,498 adjacent reference steps: 265 identity-continuous matched
pairs, one different-model-ID pair and 6,232 steps lacking one or both matched
model endpoints. The 65-cell R/Python parity CSV was **not** among the uploaded
review files, so parity is log-confirmed, not independently re-read cell by
cell. PR #98 was already merged; this is an evidence-status update only.
The validation certifies arithmetic consistency of image-space measurements
conditional on the published annotations, **not** fish biological IDs,
surveyed underwater XYZ, measured physical time or feeding/welfare effects.

The broader external-data handoff for physical-survey/ID/tank evidence is in
[Milestone 09 external validation readiness](M09_EXTERNAL_VALIDATION_READINESS.md).
