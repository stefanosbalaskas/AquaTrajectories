# AquaTrajectories — nine-milestone evidence and scientific release gate

**Verified development checkpoint:** 12 November 2026, after
Waves 13A–13E, main commit `bb2d9b20965647f2041bcacafed877861936c0a7`.

The repository now contains real original fish-video inference and
tracking executables, an offline 2D/3D explorer and simulated ACI
controller, and an integrated timing/XYZ/sensitivity validation
framework. **This is not independent physical/biological validation.**

The machine-readable registry
`inst/evidence/scientific-validation-gates.json`
covers each of the nine user-prioritized scientific milestones.
The stdlib Python checker
`inst/python/aqt_scientific_release_gate.py`
verifies that every priority has an engineering state, reference PR
and a specific still-missing empirical scientific acceptance step.

## Two distinct qualification modes

**Engineering registry completeness:**

    python inst/python/aqt_scientific_release_gate.py \
      --manifest inst/evidence/scientific-validation-gates.json \
      --mode engineering_registry \
      --report readiness.json

This validates a declared inventory and outputs a derived evidence
summary. It **cannot authenticate an external third-party measurement**.

**Scientific release request:**

    python inst/python/aqt_scientific_release_gate.py \
      --manifest inst/evidence/scientific-validation-gates.json \
      --mode scientific_release

This currently **exits nonzero (2)**, preventing an accidental
suggestion that all 9 scientific acceptance gates are satisfied.
Setting a self-declared `scientific_certified: true` does not bypass
the guard: the present checker rejects such self-certification entirely.
The validator will require a future independently audited extension
and real source evidence before scientific release can be considered.

The CI workflow asserts both sides: well-formed engineering registry,
and rejected unsupported scientific release.

## Actual current status

| Priority | What is already executable | Independent acceptance still missing |
| --- | --- | --- |
| 1. Fish detection | 149-frame Oxford frozen model end-to-end; 181 detections >=0.25; F1 0.696 at confidence 0.50 against source-final boxes | Prediction-blind independent holdout and cross-species/tank AP/F1 |
| 2. Fish identity | 177 ByteTrack observations from newly inferred fish detections; 1,584 track observations from previous Oxford source detections | Independent multi-fish ID labels; official HOTA/IDF1 and occlusion failures |
| 3. Multicamera sync | Native affine heldout marker model integrated into protocol | Verified physical camera exposure pulses; true cross-view fish matches |
| 4. Physical underwater 3D | Refractive stereo target trial holdouts and XYZ error metrics | Surveyed underwater target coordinates, independent calibration, real tank/lighting/depth |
| 5. Joint uncertainty | Detection-dropout Markov sensitivity, correlated camera/refraction and identity scenarios | Measured joint error model and heldout uncertainty interval coverage |
| 6. Behavioural inference | Event-aligned kinematics/HMM/functional/GLMM foundations | Independent biological reference labels and replicated, randomized tanks |
| 7. Unified 3D explorer | Offline local video, PTS, observed 2D/3D positions, event browser and reviewer draft notes | Full real multi-camera usability and expert annotation verification |
| 8. ACI | Offline controller dry-run with operator approval reference, command constraints and emergency-stop | Ethics, physical device trials, tested hard stop and biological welfare outcomes |
| 9. Scientific validation/release | R/Python/JS CI, public source hashes and reproducible benchmark artifacts | Independent replicability, licensing, certified physical/biological accuracy and reviewed manuscript |

## Original published source caution

Oxford Detect+Track source annotations **may have been generated with
model-assisted review**; source-label agreement is not prediction-blind
scientific accuracy. The single Oxford `F30_T15.mp4` clip does not
offer independent multi-fish identity ground truth. Published 3D-ZeF
labels are not independently surveyed physical underwater targets.

Do not use source performance as universal fish-species/tracker
validity. All evidence must retain model weight SHA-256, source
recording and clock, reference annotations, confidence/IoU thresholds
and original video/source licence requirements (Oxford CC BY-NC 4.0).

## Immediate independent empirical dependencies

See [umbrella issue #51](https://github.com/stefanosbalaskas/AquaTrajectories/issues/51)
and [official tracking gate #46](https://github.com/stefanosbalaskas/AquaTrajectories/issues/46).
The next real scientific verification needs:
1. Access to separately reviewed multi-fish video with real tracks and
   persistent identities; locked model and official TrackEval.
2. At least two physically synchronized camera recordings and heldout
   independent exposure pulses.
3. Independently surveyed XYZ underwater targets with disjoint fit
   and holdout assemblies and optical metadata.
4. Ethically approved animal observations, expert-validated fish
   behaviour/welfare labels and independently replicated tanks.
5. Full researcher UI/device safety and independent scientific audit.

This document is a traceable status statement, not a claim that
unavailable empirical or ethical work has been completed.
