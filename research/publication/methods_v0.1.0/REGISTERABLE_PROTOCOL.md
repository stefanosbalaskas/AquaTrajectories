# Registerable protocol — independent assessment of AquaTrajectories

**Protocol version:** methods-v0.1.0 / 2026-11-16. **Registration status: NOT REGISTERED.** Freeze hypotheses, thresholds, splits, independent labels and hardware/survey criteria **before** first heldout evaluation. External collaborators should review this document before registration. If any change occurs later, record an amendment, timestamp, reason and whether outcomes were seen.

## Research questions and estimands

- **RQ1 detector portability:** On never-trained-on recordings, what are precision/recall/F1/AP of a frozen fish-trained detector, stratified by scene and species, compared with prediction-blind reference boxes?
- **RQ2 tracking:** On exactly the same predicted boxes, what are differences between a prespecified ByteTrack implementation and an independently defined IoU/Hungarian baseline in HOTA, DetA, AssA, IDF1, IDSW and fragmentation? Main estimand: mean paired *recording-level* difference in HOTA, with per-recording differences and uncertainty.
- **RQ3 synchronization:** How accurately does an affine cross-camera clock transform map independently verified shared exposure markers *not used for fitting*? Main outcomes: holdout absolute time error distribution, max error, RMSE and drift parameter.
- **RQ4 absolute XYZ:** How close are refraction-aware reconstructed points to **separately surveyed** true underwater XYZ coordinates on disjoint physical target boards? Main outcomes: Euclidean 3D RMSE, x/y/z signed bias, failed reconstruction fraction and depth-stratified errors. Compare with a prespecified alternative using identical images/targets if technically applicable.
- **RQ5 uncertainty:** Do empirical error-component models produce expected interval coverage on heldout targets/trajectories, and are measurement errors propagated into movement/event analyses without hidden fish-frame independence assumptions?
- **Exploratory RQ6 biology/ACI:** Only if independent reference ethology, approved trials, real device response records and multiple randomized tanks are available: estimate event/treatment contrasts and evaluate biological construct validity. Otherwise report **NOT ASSESSED**.

## Study units and sample planning

**No sample size or power has been established yet.** Before registering, inventory legally accessible recordings, species, tanks, original 2D/3D annotations, physical targets and clock markers. Choose study-level accuracy precision targets and power/Monte Carlo sampling calculations informed by pilot error variability, **without examining the intended final holdout**. Record the unit used for each question:

| Component | Unit that controls generalization | Repeated measures |
|---|---|---|
| 2D detection | Independently heldout **recording / tank / domain** | frames, images, fish boxes |
| Tracking | Independently heldout **recording** | fish/frame assignments |
| Exposure synchronization | real camera session / timing trial | physical markers |
| Physical XYZ | independent target assembly / tank / camera setup | multiple target locations |
| Joint coverage | heldout trial or recording / target-group | samples/frames in trial |
| Animal intervention | randomized independent **tank** | fish, events, frames, sessions |

Do not use fish frames as independent replicates in treatment experiments. Predefine a split table with `split = train | calibration | pilot | test`, and annotate source overlap. A and B from one source do not automatically constitute independence if either model's training data contain them.

## Source families and their legitimate roles

1. **Oxford Detect+Track (2025):** original GoPro-derived videos, checkpoint and published final annotations. Demonstrates source-video feasibility; initial source labels may be model-assisted and some video has largely single-fish content. Not independently blinded external multi-fish identity truth.
2. **Fraunhofer HHI ricefish A/B:** originally annotated crowded fish image sequences and persistent source IDs. Treat source annotations as potentially semi-automatic, verify rights/provenance and request prediction-blind adjudication for a genuinely independent evaluation.
3. **SFISHTRACK:** candidate externally labeled fish datasets spanning video scenes; acquire legally accessible original videos and audit annotation independence before including in preregistered holdout.
4. **3D-ZeF:** stereo GoPro and source 3D tracks for source-label agreement and identity benchmark. Do **not** relabel source reconstructed fish positions as independently surveyed metrological XYZ.
5. **New physical underwater tank trials:** required for actual exposure synchronization and absolute XYZ; separately measure underwater surveyed targets, camera parameters and independent fit/test target groups.

Dataset source identifiers, original video hashes, weights hashes, permissions, label history, frames and splits must be committed to a frozen manifest. Do not commit restricted source recordings to GitHub.

## Acquisition and reference adjudication

- Preserve original files, video-local frame PTS, dimensions, camera orientation, source ID, temperature/optical context where measured, and SHA-256.
- Define and retain a complete frame manifest (including reviewed zero-fish frames); no-fish/unreviewed are different states.
- Before showing predictions to adjudicators, commission at least two qualified annotators on heldout frames/tracks selected by a sampling plan independent of model outputs. Record annotator ID, blindness, reviewed timestamps, occlusions, unknown identities, reconciliations and adjudication policy. Verify identity persistence only where justified; allow unresolved matches.
- Bound annotation labor to actual feasible sources, and predefine how disagreement and partially visible fish will be handled. Do not coerce uncertain instances to GT.
- Video inference and tracking must receive no GT boxes/IDs as input in end-to-end benchmarks. Oracle-box association remains separately labeled.
- Freeze model weights and source revisions; preserve preprocessing, class schema, image resize, confidence/NMS, association and postprocessing settings.
- If Oxford or Fraunhofer labels derive from the model evaluated, mark bias as a limitation; report the separate blinded subset when available.

## Exact benchmarking and physical protocols

**2D detection:** use IoU 0.50 as primary localization threshold; IoU 0.75 sensitivity where meaningful. Predeclare score thresholds 0.25, 0.50 and 0.70; evaluate AP with recorded integration conventions, ignored/difficult labels and complete frame denominators. Select one prespecified primary operating point **before holdout analysis**. Avoid post hoc "best-F1" tuning on test.

**Identity:** official pinned TrackEval HOTA averaged over its usual localization thresholds; report DetA/AssA and IDF1 plus CLEAR MOTA/IDSW. Compare two trackers on identical detector outputs, recording-scoped IDs and fixed params. Report failures in dense schools, source-defined overlapping rectangles, reflections, lighting, species and occlusion reference strata, with unknown annotations separate.

**Multiview synchronization:** record source camera-local timestamps and independently verified physical shared pulses. At least four distinct calibration pulses and at least two disjoint heldout pulses per session/camera are required by existing source intake contracts; more markers across a session are desirable and should be planned from measured drift precision. A video-file start time alone does not qualify. Fit affine mapping and report heldout timing error; preserve raw and transformed time. For rolling shutters and varying jitter, quantify limits rather than assuming a global exact time.

**Physical targets:** independently survey target coordinates in a declared metric coordinate system over several depths and image corners. Each trial has separate fit and holdout board assemblies (source minimum six fit and three heldout targets) and records actual camera K/distortion, extrinsics, glass geometry and refractive assumptions. Fit only on intended calibration targets; evaluate on truly independent target positions/assemblies. Require complete target denominators and classify invalid 3D outcomes. Source 3D fish labels do not substitute physical survey truth.

**Joint uncertainty:** derive detector/ID/timing/refraction/pixel residuals from designated calibration observations. Predefine covariances or resampling blocks and assess empirical coverage against heldout independently measured truth; if coverage cannot be validated, report only model-conditional scenario ranges. Propagate labels as discrete alternatives where ambiguity exists rather than forcing a continuous Gaussian identity error.

**Behaviour/ACI:** treat behaviour and animal welfare as external biological constructs requiring expert validity, ethical approval and replicated independent tanks. Device serial/stop dry-runs are not physical actuator certification. Drop this layer from empirical conclusions if appropriate real data are unavailable.

## Bias reduction and validity safeguards

- Sequence-/tank-level splits, not random nearby frames; disclose missing domains and possible pretraining overlap.
- Freeze preprocessing and thresholds; training/tuning/test boundaries are enforced in the manifest.
- Include failure cases, empty frames, missing identities and nonconvergence in the analysis, never only successful reconstructions.
- Keep GT and predictions separate; identify sourced labels that may have been machine-assisted.
- Blind at least some adjudication to evaluated predictions, record disagreements, document expert qualification.
- No fixed universal "acceptable RMSE" is asserted before specifying tank size, study question and physical measurement precision; predefine domain-specific tolerances in the registered study plan.
- Prevent metric selection from the test set; preserve baseline and sensitivity definitions.
- Track annotation costs, CPU/GPU and version portability, and run equivalent inputs for all comparison methods.

## Deviations, decision rules, registration, reporting

**Before acquisition:** populate `schemas/source_inventory.csv`, `schemas/split_registry.csv`, `schemas/model_registry.csv`, `schemas/annotation_audit.csv`, `schemas/physical_targets.csv`, and `schemas/pulse_markers.csv` with authenticated *original* sources. These headers are templates, not evidence.

**Before unblinding test:** publish/timestamp the metric set, primary threshold and applicable power/precision plan; lock the repository revision, model/weights hashes and full code environment. Submit actual preregistration to an accepted registry if required; record its returned URL/time, not a guessed ID.

**During evaluation:** freeze append-only signed or independently archived manifests; distinguish data cleaning that occurred before and after unblinding; audit mismatches.

**After evaluation:** publish complete benchmark tables, numerical definitions, numerator/denominator logic, confidence intervals, real hardware and survey error, provenance files, licensing, versioned code and omissions. Do not update `scientific_certified` booleans in the source registry without independently reviewed scientific evidence.

**Registration stamp:** NOT REGISTERED · **Ethics approval number:** NOT SUPPLIED · **Actual independent empirical outcomes:** NOT PROVIDED.
