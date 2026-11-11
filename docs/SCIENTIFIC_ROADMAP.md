# AquaTrajectories scientific roadmap

## Wave 1 — Native R foundation (source delivered on feature branch)

Canonical trajectory structure, long-form CSV adapters, timestamp-aware 2D/3D kinematics, group nearest-neighbour distance/polarization, frame-level QC, experimental-event alignment, LED-marker affine clock fitting, calibrated pinhole DLT triangulation of KNOWN pairs, 2D and optional 3D graphics, and deterministic tests.

This is a development implementation, not independent scientific qualification.

## Wave 2 — Detector and tracker reliability

Ground-truth precision/recall/F1/mAP/IoU; TrackEval/HOTA/IDF1/identity-switch adapters; recording and annotation provenance; structured manual corrections, uncertainty flags and benchmarking against MoveR, pathviewr, trajr and swaRm.

## Wave 3 — Multiview fish reconstruction

Camera rig objects and calibration import; explicit exposure synchronization checks; fisheye/lens geometry; aquatic glass/water refraction using validated existing models; cross-view correspondence hypotheses (with ambiguity); general 3D schooling and voxel occupancy; reprojection and metrology benchmarks.

## Wave 4 — Statistical and uncertainty methods

Joint perturbations of timing, calibration and plausible identity assignments; interval coverage; spatial/temporal smoothing sensitivity; FPCA/MFPCA, HMM, GAMM/GLMM, functional random effects, event-aligned recovery; known-truth multilevel tests respecting tank-level experimental units.

## Wave 5 — Publication and ACI

Interactive multi-trajectory 3D dashboards; time-locked school dynamics; figures and reports; device-action/controller/actuator telemetry; animal-contingency and choice methods; published research software benchmarks.

## Scientific contracts

1. Camera-local fish IDs are not permanent across cameras or sessions.
2. A missing z for ordinary 2D means unknown depth, not z=0.
3. Detection/tracking/3D reconstruction are separately validated stages.
4. Simple pinhole geometry does not correct air/water/glass refraction.
5. Camera-clock marker fitting does not guarantee synchronized shutter exposure.
6. Tank-level treatment effects require appropriately replicated tanks.
7. Locomotor features do not directly establish stress or positive welfare.
8. Measurement-error intervals cannot claim calibrated coverage without simulations and real validation.
9. An optional EyeTrajectories bridge may reuse only qualified, explicitly audited R methods.
10. CRAN checks and scientific validity are distinct.

## Planned publication

From Pixels to Behaviour: AquaTrajectories, an R Framework for Uncertainty-Aware 2D/3D Aquatic Animal Movement and Event-Aligned Inference.

No first-in-field claim is made for trajectory, stereo, or multi-camera tracking. Novelty must be established by demonstrating verified effects of error propagation on behavioural and inferential conclusions.

## Wave 3B — Geometry hypotheses and conditional pixel uncertainty

Implemented in the development branch: camera-time candidate enumeration,
reprojection ranking without identity claims, explicit documented reviewer
selections, and Monte Carlo pixel-localization uncertainty for verified
pinhole stereo points. Real underwater calibration, multiple-ID hypotheses,
clock/calibration correlated uncertainty and biological inference remain open.


## Wave 4A — Event-epoch summaries and independent-tank contrasts

Descriptive event windows, tracking-gap-safe trapezoidal behavioural means,
tank design audit, nonparametric within-treatment tank-resampling contrasts,
and experimental-unit-correct plots. No frame-level inferential p-values
or unwarranted causal effect claims. Experimental-design simulations,
hierarchical mixed models and cross-stage measurement uncertainty remain
future qualification work.


## Wave 4B — Conditional trajectory measurement sensitivity

New modules for empirically inspected point-localization residuals,
observation-correlated 2D/3D spatial error scenarios, whole-track and
event-aligned metric propagation, conditional quantiles and 2D/3D
scientific overlays. Not a joint model for calibrated XYZ, species,
experimental-unit and camera uncertainty. Real underwater tests,
coverage studies, and coherent cross-view error modelling are open.


## Wave 5A — Native trajectory comparison and dense-grid multivariate PCA

Implemented: deterministic multivariate 2D/3D dynamic time warping,
within-session/camera scoped distance matrices, observed-position RQA,
recurrence visualization, relative-time dense-grid multivariate PCA
and mode plots. Missing paths are not silently imputed. Qualified sparse
FPCA, functional mixed effects, irregular longitudinal uncertainty
and EyeTrajectories parity remain future work.


## Wave 5B — fish-school geometry and interactive spatial outputs

Implemented candidate methods: simultaneous camera-scoped pairwise
distances, centroid and radius of gyration, school extent, thresholded
spatial edge lists, observed 3D voxel Shannon entropy, and optional rgl
3D school/voxel graphics plus base-R group temporal plots.
True aquatic refraction correction, 3D metrology benchmarks and welfare
interpretations remain unqualified research work.


## Wave 6A — bounded refractive optics primitives

Implemented an explicitly single-planar-interface Snell ray tracer,
two-view forward-ray midpoint triangulation and known-landmark ray QC.
The optics contract rejects misleading claims of complete flat-port
glass/water calibration. Thick glass ports, real camera parameter
fitting and independent underwater 3D metrology remain future work.


## Wave 6B — discrete identity-assignment uncertainty

Implemented whole-suffix fish ID-switch scenarios, auditable original
labels, and propagation of alternative assignments into path/event
summaries and independent-tank contrasts. Measurement sensitivity and
tank-bootstrap sampling variability remain separate outputs.
Independent video annotation and uncertainty calibration are pending.


## Wave 6C — sparse functional data and tank-nested modelling

Implements a ragged-list adapter with exact observation support, a
time coverage audit, an optional independent fdapace sparse-FPCA
backend, and a fish-within-tank two-epoch mixed model using nlme.
Qualifying EyeTrajectories R functionality requires strict cross-language
oracle comparisons and independent contract certification first.
Joint measurement/identity/tank uncertainty is still a research goal.
