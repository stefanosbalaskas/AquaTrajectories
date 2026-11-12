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


## Wave 6D — parallel flat-glass port geometry

Adds two-interface air-glass-water pixel-to-water ray tracing,
with independent camera/landmark QC and known-geometry regression
tests. Supports parallel planar glass walls only; measured intrinsics,
extrinsics, surface normals/thickness and validation targets remain
the user's responsibility. Joint optical parameter uncertainty with
fish identity and tank-level inference remains future work.


## Wave 7A — reviewed refractive 2D-to-3D fish tracking

Adds a time-stamped 3D fusion path for explicitly reviewed camera
pixel correspondences under one- or two-interface Snell models,
with source provenance, known clock tolerance, invalid-position
handling and physical ray-separation QC. Experimental metrology,
identity ambiguity, and camera-calibration uncertainty remain
separately qualified research topics.


## Wave 7B — coherent optical / ID sensitivity with tank replication

Implemented conditional scenario draws for shared optical camera parameters,
per-pixel localization noise and externally postulated discrete fish identity
swaps, propagated to 3D trajectories, event windows and independently
tank-replicated treatment-group contrasts. Scenario inclusion and tracking
gaps are audited. Rotation, synchronization uncertainty, automated cross-view
identity probabilities, calibrated real-video error distributions and joint
confidence intervals remain unqualified.

## Wave 7C — independent 3D truth and limited camera parameter refinement

Added reference-landmark XYZ reconstruction benchmarks with valid/invalid
denominators, per-axis 3D biases/RMSE, depth-stratified accuracy and
bounded single-camera translation refinement using disjoint training and
heldout physical targets. Neither source calibration parameter covariance
nor full glass/lens/rotation optimization has been certified.

## Wave 8A — bounded native behavioural change-point segmentation

Implemented finite penalized SSE segmentation, event-onset delay
diagnostics and observed-vs-fitted graphical outputs. Missingness
and large timestamp gaps are rejected; video-frame sample counts
never replace independently treated tanks. Species-calibrated state
models, HMMs and qualified EyeTrajectories-native methods remain
separately unimplemented.


## Wave 8B — event-aligned functional analysis with independent tanks

Implemented observed-only, onset-protected interpolation onto a declared
real-time grid, support audit, and equal-weight independently
replicated tank-level functional treatment contrasts. Separate
resampling bands describe sampling variation only; optical error,
discrete fish IDs, causal identification, GLMM/GAMM and sparse FPCA
inference are not automatically addressed.

## Wave 9A — time-indexed measured 3D fish scenes

Adds observation-only physical XYZ scene snapshots, gap-separated
trajectory tails, event annotations, finite storyboards, headless
orthographic projections and optional rgl 3D display. No missing
fish position is silently carried forward; it is not an integrated
video-playing, uncertainty-volume or species-body-modeling interface.


## Wave 10A — animal-device closed loop and genuinely offered choices

Implements opportunity-level fish action and detector/controller/physical
actuator timeline validation, true/false physical activation,
contingency and stage latency. Separately represents physically offered
alternatives, exercised selections, conditional per-option exposure,
and normalized inequality of actual multi-option exercise among fish.
No automatic video-to-action algorithm, yoked-control causal estimate,
preference stability or biological welfare validation is claimed.


## Wave 8C — time-varying nested fish/tank longitudinal model

Adds strict validation of complete, equally spaced event-relative
fish curves with independent tank replication, and a Gaussian
nested tank/fish random-intercept natural-spline model with
optional AR(1) within-fish residuals through independently
maintained nlme. Real-video/physical calibration and model
coverage/power remain pending; sparse/irregular mixed functional
models require separate validation.

## Wave 9B — multimodal optical and fish-identity XYZ visualization

Provides visible-by-scenario physical XYZ fish cloud samples,
explicit missing/stale fish rejection, label assignment-change
rates and descriptive marginal quantiles; base projected scatter
and optional rgl XYZ scatter. The full cloud retains multimodal
identity alternatives. No calibrated uncertainty ellipsoid,
real-video overlay, joint statistical confidence model or
independent underwater metrology claim is made.

## Wave 7D — heldout camera clock drift validation

Adds per-session affine camera timing alignment with disjoint physical
marker training/validation sets, fit/heldout clock residuals, ppm drift,
and strict timestamp transformation with preserved raw clock values.
A good residual is conditional on independently verified common pulses;
rolling shutter, nonlinear jitter, event-log clock registration and
joint clock/optics error propagation remain open research tasks.

## Wave 7E — explicit Brown perspective lens correction before flatport optics

Adds externally parameterized radial/tangential source-pixel correction,
validated numerical inversion, canonical fish-track provenance and
Snell air–glass–water integration. Camera K and lens parameters are
supplied, not estimated or calibrated, and fisheye/omnidirectional
GoPro modes are not implicitly supported. Real target metrology,
uncertainty of lens parameters and physical 3D reference comparison
remain separate scientific gates.

## Wave 8D — gap-safe conditional Gaussian behavioural states

Implements externally parameterized 1D Gaussian HMM posterior probabilities,
Viterbi state decoding, conditional sequence likelihood and fish-scoped
sample-state/transition summaries. Explicitly splits tracking gaps,
unobserved points and tank/fish/camera/session boundaries; short observed
runs remain unclassified. This is NOT automatic HMM parameter estimation,
species-specific state learning, continuous-time transition modelling,
welfare diagnosis or experimental tank-level hypothesis testing.
Independent 3D measurement/identity uncertainty and real-video
validation remain unqualified.

## Wave 8E — fixed-emission Baum-Welch transition learning and holdout audit

Implements native log-domain EM for HMM initial distributions and sample-step
transition probabilities, holding externally specified Gaussian state
means and SDs fixed; split sequences respect observed gaps and scoped
animal/tank identities. Out-of-sample conditional log likelihood explicitly
rejects reused fish scopes and, by default, reused independent tanks.
This is neither full HMM emission estimation nor calibrated fish welfare
classification. Nonrandom missingness, changing frame intervals,
species-specific reference labels, uncertainty propagation, heldout
multi-camera calibration, and tank-treatment effects remain open.

## Wave 8F — synthetic independent-tank HMM parameter recovery

Adds local-seeded, RNG-restoring simulations with known state paths,
Gaussian emissions and latent transition matrices across multiple
independent synthetic fish/tanks. Fits transition/initial probabilities
on explicitly designated training tanks; audits heldout state confusion,
state accuracy, per-step likelihood and matrix error on completely
disjoint synthetic tanks. Ground-truth availability here is created
by the simulator, not obtained by manual fish annotation. A positive
simulation result does not certify real fish movement, multi-camera
identity, underwater XYZ accuracy or welfare.

## Wave 8G — HMM state event alignment and independently replicated tanks

Connects state-decoder posterior probabilities to externally recorded
feeding, enrichment or device events. Requires a single event and
single recording session per tank, complete within-fish baseline/
response support, fixed treatment assignment and >=2 independent
tanks per arm. Equal-weight fish-to-tank aggregation feeds the
preexisting independent-tank bootstrap contrast. Effects describe
sample-averaged posterior occupancy and are not frame-level,
measurement-error-calibrated, causal, biological-welfare or
time-weighted occupancy estimates. Repeated events, crossovers
and irregular sampling demand a different model.
