# AquaTrajectories — independent physical and biological validation protocol

**Version:** 1.0 · 20 November 2026  
**Status:** READY FOR DATA INTAKE; PHYSICAL AND BIOLOGICAL CERTIFICATION NOT YET ACHIEVED  
**Purpose:** close the remaining *external scientific* validation requirements without erasing the completed M06–M08 computational evidence.

## 1. The distinction that must remain explicit

M06 measured performance of a fixed externally trained fish detector and ByteTrack association against published BrackishMOT reference annotations. M07 independently reproduced R/Python frame-indexed calculations; M08 measured localisation and step-error support conditional on published-annotation matching. These are genuine empirical software and published-reference studies. They do not supply measured exposure times, surveyed underwater XYZ positions, independently confirmed biological fish identities, calibrated joint error coverage or replicated treatment outcomes.

The next study must add new *independent reference observations*. A new table of derived model positions, a 3D-ZeF source XYZ export, or a third-party source author's AquaCal RMSE cannot by themselves fill this requirement for AquaTrajectories. No software test can convert such quantities into independently surveyed physical truth.

## 2. Tier P — underwater physical metrology

### 2.1 Acquisition design

Record two (or more) genuinely calibrated camera views of a stationary or deliberately moved, traceably measured 3D target in water. Preserve the original video bytes, format, frame timestamps, camera intrinsics, distortion, extrinsic pose, optical interfaces (air/water/glass thickness and refractive indices as applicable), tank geometry, target layout, survey methodology and measurement precision. If camera timings matter, record common physical exposure markers and their per-camera extraction, rather than inferring simultaneous capture from identical nominal FPS.

Separate calibration and held-out assessment *at the board pose/location level*. Ideally vary depth, camera range, image location and orientation, and include targets both inside and outside the central calibrated volume. A board corner used in fit may be used again at a genuinely disjoint held-out pose, but do not split correlated image samples of the same pose between calibration and test. Record any unstable point, detection failure, missing pose and reconstruction rejection in the original denominator. The validation sample must contain independent held-out target configurations and repeated acquisitions; a single static target should be designated a feasibility exercise, not general physical accuracy evidence.

### 2.2 Required immutable inputs

1. **Holdout survey**: `experiment_id`, `session_id`, `board_pose_id`, `landmark_id`, surveyed XYZ in mm, method, physical uncertainty, independently identified measuring operator and source evidence digest. Exact original measurement file and photos/survey sheet must be retained.
2. **AquaTrajectories reconstruction**: the same keys and predicted XYZ, versioned source/model digest, camera calibration version, camera exposure/time association, and explicit failures. If prediction is not produced by AquaTrajectories itself, label it external and do not attribute its accuracy to the package.
3. **Predeclared fit–holdout mapping**: board pose IDs, evaluation grouping and recorded split selection *before* viewing heldout errors.
4. **Source camera and calibration records**: original images, lens/calibration files, refractive model assumptions, exposure-pulse markers and hash-linked configurations. Hashes are file integrity evidence, not survey independence proof.

The included `external_validation/` templates define this minimum structure. The stdlib-only checker `m09_external_physical_gate.py` calculates descriptive errors from supplied exact holdout correspondences, refuses source-derived stereo XYZ presented as surveyed truth, checks missing or duplicate records, enforces fit/holdout registration and writes a new immutable source-hash-linked report. It **never** declares scientific external certification from a CSV alone.

### 2.3 Numerical outcomes

For each eligible held-out target point, let \(\mathbf{e}=\widehat{\mathbf{x}}-\mathbf{x}_{surveyed}\). Report count, original surveyed denominator, success/failure rate and support by target pose, depth and camera geometry. Among successful results, report axis-wise bias \(\overline{e_x},\overline{e_y},\overline{e_z}\), axis-wise MAE and RMSE, Euclidean position MAE/RMSE, tail error quantiles, signed spatial bias, and sensitivity to source survey uncertainty. Include all invalid/unreconstructed targets in the denominator rather than silently dropping them before error reporting. Quantify differences between central and edge-of-volume regions and between independent sessions or tank/camera rigs.

A reference target's known inter-corner length provides a further check independent of the calibration output. Report measured–surveyed length error and errors in XYZ separately. Reprojection or ray-separation errors remain internal-consistency descriptors. A physical accuracy statement requires independently surveyed targets and the actual AquaTrajectories predictions for those targets. Prespecify tolerances for the intended biological application, target count/precision and heldout analysis before seeing the test values; do not choose an accuracy threshold post hoc to make the method pass.

### 2.4 External resources and their evidence levels

- **FishSizing** (Muntaner et al., 2026, Zenodo 10.5281/zenodo.19408363) includes independent physical fish-length measurements and stereo camera metadata, but the main raw archive alone is about 25.2 GB and related volumes are separate. The CSVs and authors' reported results are useful source records; without running the actual underwater stereo frames and the AquaTrajectories length/XYZ pipeline, they are *not* independent validation of AquaTrajectories.
- **3D-ZeF** (Pedersen et al., 2020) supplies published source-reconstructed zebrafish XYZ labels and multiview camera evidence. It is valuable for source-reference 3D trajectory and ID association, but its 3D fish labels are not surveyed physical fiducials.
- **AquaCal** (Lancaster and McGrath, 2026) reports errors from its own refraction-aware multi-camera calibration and physical target experiments. Such metrics can provide an external comparator; they cannot be transferred into an AquaTrajectories results table unless our methods are run on the same independently checked heldout target observations.

## 3. Tier I — independently verified biological fish identity

For the same original videos and a prespecified representative set of frames/occlusions, obtain annotations from at least two trained reviewers **blinded to the algorithm's assigned IDs**. Record original frame hash, independent fish label, box/head position, species if reliably established, visibility/occlusion and ambiguous/unresolvable status. Preserve both review passes, disagreements and the adjudication decision; adjudication cannot silently overwrite independent raw labels. Verify source-video identity continuity with external tag marks or continuous video evidence when possible. It is acceptable to abstain where fish are indistinguishable rather than forcing certainty.

Report inter-reviewer agreement on labels and localisation, adjudication/disagreement counts, and benchmark performance evaluated against the frozen independent labels. Stratify by crowding, target size, lighting, apparent depth, occlusion and recording. Recompute HOTA, DetA/AssA, IDF1 and movement-eligibility fractions for *the same frozen model predictions*, not a detector tuned on the review labels. This explicitly distinguishes a revised biological-reference benchmark from the original publisher-reference comparison.

## 4. Tier B — scientifically interpretable fish behaviour

A feeding or stress experiment is a separate prospective design. It must include actual event-onset/offset logs, verified camera timing and camera/tank calibration, declared movement and group outcomes, baseline/control periods and independent experimental units. If treatments are assigned to tanks, replicate tanks and randomise at tank level; thousands of frames from one tank do not multiply the treatment sample size. Specify blocked or descriptive outcomes when replication is insufficient. A five-fish, two-GoPro pilot may evaluate feasibility and repeatability but cannot justify population causal inference without independently treated replicated tanks and appropriate controls.

For stress or welfare, triangulate locomotor features with independently validated ethological or physiological measures; a moving-speed threshold or HMM label is not independently a welfare diagnosis. Report missing measurements, tank nesting, fish nesting where identities are supported, temporal correlation, exclusion reasons and sensitivity to tracking and calibration error. Determine biological thresholds and power/precision before confirming treatment effects.

## 5. Release gates and stop conditions

| Gate | Evidence required | Current status (20 Nov 2026) |
| --- | --- | --- |
| M06 fish detector/tracker source evaluation | Frozen real BrackishMOT plus model output and official metrics | **PASS, publisher-reference conditional** |
| M07 numerical computation | Native R vs independent Python source replay | **PASS** |
| M08 conditional movement | IoU-matched real boxes, step and group source ledgers | **PASS, severe attrition** |
| M08 native R real-data parity | 65 R/Python checks, local console and native file hashes | **PASS (log-confirmed), no 65-cell upload** |
| Physical speed | Measured exposure time and calibrated scene scale | **BLOCKED** |
| Independent underwater XYZ | Surveyed holdout poses, original predictions, raw calibration and measured references | **BLOCKED** |
| Independent animal identities | Prediction-blind human review and frozen source-frame lineage | **BLOCKED** |
| Empirically calibrated joint uncertainty | Independent residuals, heldout interval coverage and dependence-aware sampling | **BLOCKED** |
| Feeding/stress/treatment inference | Event clocks, reference outcomes, ethics and replicated tanks | **BLOCKED** |

Do not merge a future claim of scientific physical or biological accuracy into a release note until the corresponding reference records have been inspected, rerun and externally reviewed. The accompanying manuscript is a private software/methods working draft; its existence is not a journal acceptance or a completed external validation certificate.

## 6. Intended next actions when physical records are supplied

Acquire source survey and calibration targets, freeze the split and original hash manifest, run `aqt_target_holdout_benchmark` / relevant existing reconstruction functions on actual heldout physical targets, cross-check results with the independent Python audit, report all valid and invalid positions, and only then revise the quantitative manuscript results. Separately arrange blinded fish-ID review and collect independently replicated behavioural experiments. Preserve the original M06–M08 negative benchmark as an immutable baseline, even if newer detectors subsequently improve.