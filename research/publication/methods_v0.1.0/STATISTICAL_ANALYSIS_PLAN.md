# Statistical analysis plan (SAP) — dossier methods-v0.1.0

**Status:** prepared before independent holdout outcome inspection. Researcher must lock study-specific sample sizes, precision tolerances, source hierarchy, power assumptions and exact split IDs during real preregistration; no result has been computed for this plan.

## I. Outcomes, estimands and denominators

**Detection:** `TP/(TP+FP)` precision, `TP/(TP+FN)` recall, `2TP/(2TP+FP+FN)` F1 with specified IoU rule, at prespecified detector confidence thresholds. Report TP/FP/FN integers, frame/box denominators and missing/ignored image counts. AP must include exact interpolation/integration convention and correct ignore/crowd handling (package custom AP is not a full COCO evaluator). Empty annotated frames contribute FPs when model predicts fish.

**Identity:** HOTA, DetA, AssA, LocA, IDF1, MOTA and IDSW from the *actual pinned official TrackEval* on continuous recording-local identities, including reviewed empty frames. Per-sequence HOTA is the primary comparison for ByteTrack versus a deterministic independent tracker when the detection outputs are identical. If multiple sequences exist, compute a predeclared sequence-level aggregate, and show full sequence distribution; do not pretend 101 frames give 101 independent accuracy trials.

**Clock:** for heldout marker `j`, `e_j = (a + b t_{camera,j}) - t_{ref,j}`. Report median absolute error, RMSE, maximum absolute error, slope-derived drift in ppm, extrapolation status and unmatched marker count, separately by camera session. Fit pulses and heldout pulses must be disjoint physically documented events.

**Physical XYZ:** `e_{ijk}=XYZhat_{ijk}-XYZtruth_{ijk}`. For valid points report axis-wise bias `mean(e_k)`, RMSE per axis, 3D Euclidean RMSE `sqrt(mean(||e||^2))`, MAE, median and 95th percentile Euclidean error, with 95% cluster-resampling intervals. Report invalid fraction over **all independently surveyed eligible targets**. Analyze errors by target depth, field region, board assembly and camera/tank.

**Uncertainty:** for predeclared nominal intervals (e.g. 50%, 80%, 95%), compute empirical heldout coverage, mean width, calibration slope or expected-calibration plots where appropriate, and breakdown by occlusion/tank/depth. If input intervals are only conditional sensitivity draws, **do not** claim calibrated coverage. Test robustness under nonrandom missing detections and discrete ID ambiguity.

**Behaviour:** movement quantities (speed, path, turning, zone occupancy, schooling) remain descriptive until biological labels/ethics/tank randomization are available. For an experimental effect report tank-level treatment contrast with uncertainty; fish/time observations nested in tank are repeated measurements. Never use number of video frames as a causal trial N.

## II. Confirmatory comparisons and descriptive reporting

1. **Primary tracking contrast:** paired recording-level `HOTA(ByteTrack) - HOTA(alternative)` with a prespecified two-sided 95% interval based on whole-recording bootstrap or a small-sample paired exact/permutation method. Report direction, magnitude and all individual recordings. An unpaired frame bootstrap is not acceptable.
2. **Detection:** primary frozen detector model and chosen score/IoU operating point; secondary thresholds descriptive, with explicit separation of any calibration data used to select threshold.
3. **3D:** primary holdout-target Euclidean RMSE; descriptive stratified signed biases and invalid fraction. If comparing calibration modes, use matched target assemblies while ensuring neither mode has been fitted on its test assembly.
4. **Uncertainty calibration:** simultaneous report of empirical coverage and mean width. Broader intervals achieving target coverage alone do not demonstrate good efficiency.
5. **Biological:** analysis only if the separate ethics and tank-randomization gate passes. Otherwise do not report animal-welfare findings.

No prespecified statistical significance threshold substitutes for accuracy assessment. For multiple unplanned exploratory tests, report effect sizes/intervals and make the exploratory nature explicit; do not relabel them confirmatory.

## III. Missing data and error cases

- **Detection failure:** evaluated frame remains in denominator; zero detections is a data state, not an error or a missing source frame.
- **Unknown identity:** do not assign an invented GT ID; exclude only from identity-scored strata with an explicit count, while preserving detection evaluation where possible.
- **Dropped frames/irregular PTS:** use observed timestamp intervals; report valid/invalid temporal spans, no nominal-FPS interpolation without separate assumptions.
- **Nonreconstructable XYZ:** remain in total target denominator as invalid; valid-point RMSE alone must be paired with invalid rate and a sensitivity bound on failure.
- **Failed calibration/sync:** expose failed sessions and prespecified rejection reasons; do not silently remove difficult trials.
- **Aborted/uncertified device trials:** stop, report as not evaluable; no physical ACI success claim.

## IV. Design/precision planning before registering

Collect pilot-only variation by whole recording and physical board assembly. Predefine desired **precision** for detection/tracking metric comparison and for physical RMSE interval width; power or Monte Carlo simulation must respect the number of independent recordings/tanks. For proposed fish intervention work, specify biologically meaningful effect size, baseline variability, tank count, stratification and dropouts with welfare review; one tank with many fish cannot provide a multi-tank treatment contrast. Do not post hoc change minimum recording counts or thresholds after inspecting test metrics.

## V. Robustness and sensitivity matrix

- Detector: training-domain versus unseen domain; thresholds .25/.50/.70; IoU .50 primary and .75 sensitivity; different fish density, lighting and source labeling history.
- Tracker: same boxes; ByteTrack versus independent IoU/Hungarian; explicit oracle-box upper-bound separately.
- Timing: withheld pulses across session; extrapolation and clock-origin audit; perturbation of residual timing within independently observed calibration ranges.
- 3D: tank depth, corner versus middle, optical models, fit/holdout board independence and invalid reconstructions; compare same targets.
- Uncertainty: joint correlated versus factorized perturbation; no-data sensitivity described as conditional; interval coverage only on externally heldout truth.
- Behaviour: unknown identities, detection dropout strata, tank-level leave-one-out stability and alternative event windows if prespecified.

## VI. Final results release controls

Before a table is completed, attach source hash, method/weights SHA, exact software commit, output hash, responsible researcher, blind reference method, split manifest, unit of replication, confidence-interval method, reviewer approval and rights statement. The accompanying fail-closed evidence audit reports missing records as *missing* and cannot generate an empirical result from schemas.

**Independent validation report:** PENDING · **Registered SAP:** NOT REGISTERED · **Real measurements:** NOT INCLUDED.
