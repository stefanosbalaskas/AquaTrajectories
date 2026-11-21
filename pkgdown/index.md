<section class="aqt-hero">
<p class="aqt-eyebrow">Open-source aquatic movement science · v0.1.2 release + 188-function development branch</p>
<h1>From aquatic observations to reproducible movement science</h1>
<p>Analyze, validate and visualize 2D/3D aquatic-animal trajectories you already have with R. Video and Python tracker adapters are optional. Start with documented synthetic examples, then bring your own records, explicit units and—where applicable—independent calibration and identity evidence.</p>
<div class="aqt-cta"><a href="articles/reproducible-research-release.html">Reproduce v0.1.2</a><a href="articles/quickstart-five-minutes.html">Run a five-minute example</a><a href="synthetic-explorer.html">Open interactive lab</a><a href="articles/plan-your-experiment.html">Plan your experiment</a></div>
<div class="aqt-badges"><span>188 R functions on main</span><span>15 reference categories</span><span>Tagged v0.1.2: 179 functions</span><span>Evidence safeguards now in main</span></div>
</section>

<div class="aqt-note"><strong>Published software:</strong> <a href="https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.2">AquaTrajectories v0.1.2</a> is the reproducible GitHub software release. The previous v0.1.1 release (not the new v0.1.2 source) is permanently archived as <a href="https://doi.org/10.5281/zenodo.24262905">10.5281/zenodo.24262905</a> on Zenodo. <a href="https://zenodo.org/badge/DOI/10.5281/zenodo.24262905.svg"><img src="https://zenodo.org/badge/DOI/10.5281/zenodo.24262905.svg" alt="Zenodo DOI 10.5281/zenodo.24262905" loading="lazy"></a> CRAN qualification is in progress; this package is not yet published on CRAN.</div>

<div class="aqt-note"><strong>Reproducible Research 0.1.2:</strong> The locked 17-row synthetic trajectory-to-QC-to-report example reproduces 10 source-eligible steps (10 cm), has independent Python source-row and Euclidean auditing, and is measured for 2D/3D runtime/memory across Linux/Windows/macOS. <a href="https://github.com/stefanosbalaskas/AquaTrajectories/blob/main/docs/RELEASE05_REPRODUCIBLE_RESEARCH.md">Exact-source release protocol and evidence</a>. A new version-specific Zenodo DOI is not yet confirmed.</div>

<div class="aqt-note"><strong>New on main:</strong> All eight evidence-safeguard improvements were merged through <a href="https://github.com/stefanosbalaskas/AquaTrajectories/pull/109">PR #109</a>. Current <code>main</code> has 188 documented R functions and 15 reference categories. <strong>These post-release additions are not part of the tagged v0.1.2 installation.</strong> The reproducible synthetic example and R Markdown analysis were qualified on Linux, Windows and macOS; original SmartFish source data and the manuscript are not hosted here. <a href="https://github.com/stefanosbalaskas/AquaTrajectories/blob/main/docs/EVIDENCE_SAFEGUARDS_V1.md">Read the scientific safeguards protocol</a>.</div>

<div class="aqt-note"><strong>Scientific status:</strong> this release is engineering-qualified, but biological identity, underwater metrology, fish welfare inference, empirical interval coverage and real actuator safety are **not independently certified**. See the <a href="articles/scientific-status.html">evidence and limitations</a>.</div>


## Evidence safeguards — know what your trajectory data can support

The new evidence layer is designed to expose specification sensitivity, unverified units, pseudoreplication and weak spatial comparisons before they become publication claims. It builds on existing QC 2.0, source-row provenance and publication graphics, and **does not require automatic fish detection or video input**.

<div class="aqt-cardgrid">
<a class="aqt-card" href="reference/aqt_compare_specifications.html"><div class="aqt-kicker">01 · Robustness</div><h3>Compare defensible estimators</h3><p>Contrast pooled, time-window, fragment and track-weighted descriptions; report denominators and flag sign reversals rather than hiding them.</p></a>
<a class="aqt-card" href="reference/aqt_measurement_contract.html"><div class="aqt-kicker">02 · Measurement</div><h3>Respect measurement units</h3><p>Separate pixel coordinates, source-reported depth and independently calibrated physical XYZ. Mixed-axis previews are display-only.</p></a>
<a class="aqt-card" href="reference/aqt_inference_readiness.html"><div class="aqt-kicker">03 · Inference</div><h3>Audit independent units</h3><p>Identify the defensible unit of analysis; tracking fragments or camera IDs do not automatically constitute animals or replicated tanks.</p></a>
<a class="aqt-card" href="reference/aqt_spatial_support.html"><div class="aqt-kicker">04 · Diagnostics</div><h3>Inspect spatial and temporal support</h3><p>Check equal-window occupancy, image-geometry associations and within-recording placebo cuts before interpreting phase contrasts.</p></a>
<a class="aqt-card" href="reference/aqt_evidence_report.html"><div class="aqt-kicker">05 · Reproduce</div><h3>Export evidence-aware reports</h3><p>Produce cautious interpretation statements, graphics and SHA-256 manifests from a source-linked synthetic research example.</p></a>
</div>

<div class="aqt-cta"><a href="https://github.com/stefanosbalaskas/AquaTrajectories/blob/main/docs/EVIDENCE_SAFEGUARDS_V1.md">Read the evidence-safeguards guide</a><a href="reference/index.html">Browse all 188 development functions</a><a href="https://github.com/stefanosbalaskas/AquaTrajectories/pull/109">View verified implementation</a></div>

**Availability:** Install `main` explicitly for these development features (`remotes::install_github("stefanosbalaskas/AquaTrajectories", ref = "main")`). The official tagged v0.1.2 release is unchanged. The safeguards are scientific diagnostics—not certification of biological identity, causal feeding effects or physically validated underwater 3D kinematics.

## Choose your path

<div class="aqt-cardgrid aqt-entrygrid">
<a class="aqt-card" href="reference/aqt_compare_specifications.html"><div class="aqt-kicker">New on main · Evidence quality</div><h3>Evaluate whether results are robust</h3><p>Audit estimator choices, units, pseudoreplication, spatial support, placebo periods and research conclusions.</p></a>
<a class="aqt-card" href="articles/reproducible-research-release.html"><div class="aqt-kicker">Already have trajectories</div><h3>Scientific Core 2.0: tracks to report</h3><p>Use 2D/3D CSVs without video or a tracker; review QC2 source rows, reproduce the independent numerical example, and export journal figures.</p></a>
<a class="aqt-card" href="articles/quickstart-five-minutes.html"><div class="aqt-kicker">New to R</div><h3>Try a complete analysis</h3><p>Five minutes: synthetic tracks → movement → event alignment → CSV exports. Confirm expected row counts.</p></a>
<a class="aqt-card" href="articles/video-to-results.html"><div class="aqt-kicker">Working with footage</div><h3>Plan video → results</h3><p>Original PTS, externally trained detector, reviewable IDs, camera geometry, explicit scientific gates.</p></a>
<a class="aqt-card" href="articles/plan-your-experiment.html"><div class="aqt-kicker">Planning an experiment</div><h3>Choose your recording setup</h3><p>One camera, two cameras, or existing footage: match the workflow to the evidence your study can support.</p></a>
<a class="aqt-card" href="synthetic-explorer.html"><div class="aqt-kicker">Interactive laboratory</div><h3>Explore fish tracking visually</h3><p>Five invented tracks, two camera projections, occlusions, identity switches, event markers and exportable teaching outputs.</p></a>
</div>

<div class="aqt-statusbar" role="group" aria-label="Current release and scientific evidence">
  <div><strong>Released</strong><span><a href="https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.2">v0.1.2</a> · 179 exports; <a href="https://github.com/stefanosbalaskas/AquaTrajectories">main</a>: 188 exports</span></div>
  <div><strong>Citable</strong><span><a href="https://doi.org/10.5281/zenodo.24262905">Prior v0.1.1 Zenodo DOI</a> · <a href="AquaTrajectories-v0.1.1.bib" download>BibTeX</a></span></div>
  <div><strong>Scientific validity</strong><span>Software contracts tested; <a href="articles/capabilities-and-validation.html">independent biological validation pending</a></span></div>
</div>

## Scientific Core 2.0 — independently reproducible research software

The completed five-milestone roadmap is available in the published v0.1.2 GitHub release: stable 2D/3D scientific architecture; source-preserving QC2; numerical/metamorphic validation; QC-aware publication figures; and cross-platform reproducible research.

**Measured release evidence:** 179 exported functions; **89.33% actual instrumented R test coverage**; **24 runtime and allocation-memory workloads on each of Linux, Windows and macOS**; and a **17-row synthetic dataset** with **10 eligible movement steps totaling 10 cm**, independently verified against an alternate Python implementation. These are bounded software tests and environment-dependent benchmarks, not biological-certification percentages or peak resident-memory measurements.

**[Complete reproducible v0.1.2 research guide](articles/reproducible-research-release.html)** · **[Full versioned evidence archive](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.2)** · **[Current scientific evidence dashboard](articles/research-evidence-dashboard.html)**

## Discover the research workflows

<div class="aqt-figure"><img src="workflow.svg" alt="Conceptual workflow: videos and metadata move through detection, tracking, synchronized multiview geometry, uncertainty, behavioural analysis and scientific review." loading="lazy"></div>
<p class="aqt-figure-caption">Conceptual software workflow, not an empirical performance result.</p>

<div class="aqt-cardgrid">
<a class="aqt-card" href="articles/video-tracking.html"><div class="aqt-kicker">01 · Acquire</div><h3>Video tracking and identities</h3><p>GoPro inputs, video PTS, YOLO/ByteTrack integration, tracker exports and manual annotation.</p></a>
<a class="aqt-card" href="articles/multiview-3d.html"><div class="aqt-kicker">02 · Reconstruct</div><h3>Multiview 3D and refraction</h3><p>Stereo rigs, clock diagnostics, Brown correction, air–glass–water optics and geometric correspondence.</p></a>
<a class="aqt-card" href="articles/validation-and-benchmarks.html"><div class="aqt-kicker">03 · Validate</div><h3>Scientific benchmarks</h3><p>Detection F1, IDF1, holdout targets, physical XYZ error and source-truth provenance.</p></a>
<a class="aqt-card" href="articles/movement-and-schooling.html"><div class="aqt-kicker">04 · Characterize</div><h3>Movement and schooling</h3><p>Speed, paths, spatial occupancy, school geometry, 3D scenes and trajectory recurrence.</p></a>
<a class="aqt-card" href="articles/behavioural-models.html"><div class="aqt-kicker">05 · Model</div><h3>Behaviour and longitudinal models</h3><p>Changepoints, Gaussian HMMs, FPCA, functional curves and nested tank/fish models.</p></a>
<a class="aqt-card" href="articles/uncertainty.html"><div class="aqt-kicker">06 · Question</div><h3>Uncertainty-aware inference</h3><p>Pixel, optical, identity and trajectory perturbations, with explicit model assumptions.</p></a>
<a class="aqt-card" href="articles/experimental-design.html"><div class="aqt-kicker">07 · Experiment</div><h3>Events and independent tanks</h3><p>Event alignment, tank-replicated summaries and defensible inferential units.</p></a>
<a class="aqt-card" href="articles/aci-workflows.html"><div class="aqt-kicker">08 · Interact</div><h3>Animal–Computer Interaction</h3><p>Telemetry, choices, access inequality and bounded device-control research protocols.</p></a>
<a class="aqt-card" href="articles/all-plot-functions.html"><div class="aqt-kicker">09 · Communicate</div><h3>All 22 plotting functions</h3><p>Demonstration figures, publication storyboards, 3D projections and reproducible graphics.</p></a>
</div>

## Choose your camera configuration

The [experiment planning guide](articles/plan-your-experiment.html) provides separate paths for [one-camera 2D tracking](articles/plan-your-experiment.html#one-camera), [two-camera 3D research](articles/plan-your-experiment.html#two-cameras), and [existing recordings](articles/plan-your-experiment.html#existing-recordings). Camera count alone does not establish physically calibrated XYZ or biological identity.

## Original video reproducibility

The [licensed DIGI4ECO video walkthrough](articles/real-fish-data-walkthrough.html) converts original underwater MP4 and source CVAT tracking annotations using actual PTS and SHA-256 provenance. These are **source-author labels, not AquaTrajectories model predictions**; the website does not redistribute original footage or claim unverified accuracy.

## Phase 3 — Research laboratory

The four new <a href="articles/research-laboratory.html">research-laboratory tools</a> move beyond static teaching figures. They include an interactive physical **single-interface 3D reconstruction example**, an opt-in **webR/WebAssembly runtime for executing real base R** code, a **locally synchronized multiview evidence viewer**, and a **privacy-preserving trajectory CSV inspector**. No original research files are uploaded.

<div class="aqt-cardgrid aqt-research-grid">
<a class="aqt-card" href="research-geometry.html"><div class="aqt-kicker">3D Geometry</div><h3>Refracted-ray laboratory</h3><p>Adjust camera baseline, water index, fish depth and localization error. Rotate the scene and inspect geometric abstentions and synthetic XYZ error.</p></a>
<a class="aqt-card" href="research-webr.html"><div class="aqt-kicker">Executable R</div><h3>Run R through webR</h3><p>On explicit request, initialize a pinned WebAssembly R runtime and execute four bounded base-R statistical demonstrations.</p></a>
<a class="aqt-card" href="research-multiview.html"><div class="aqt-kicker">Multiview review</div><h3>Inspect synchronized sources</h3><p>Use local camera videos, timing manifests, 2D points, source XYZ and event markers without manufacturing measurements.</p></a>
<a class="aqt-card" href="research-data-inspector.html"><div class="aqt-kicker">Local QC</div><h3>Inspect trajectory CSVs</h3><p>Check scoped identity/time duplicates, observed gaps, coordinate integrity and download a local quality report.</p></a>
</div>

These modules are research aids and synthetic teaching tools, **not** empirical fish-detection benchmarks, verified shutter synchronization, or underwater physical metrology. The webR page fetches its pinned interpreter from a public CDN only after you choose to initialize it.

## Scientific teaching: four interactive laboratories

Explore deterministic examples that separate **what software computes** from **what real biological observations establish**. Each exercise runs locally in the browser, uses invented inputs, and links to the published v0.1.2 R documentation.

<div class="aqt-cardgrid aqt-teaching-grid">
<a class="aqt-card" href="scientific-tracking-lab.html"><div class="aqt-kicker">01 · Evaluate</div><h3>Detector and tracker lab</h3><p>Move detection noise, missingness, false positives and ID switches; inspect computed synthetic precision, recall, F1 and identity changes.</p></a>
<a class="aqt-card" href="math-workbench.html"><div class="aqt-kicker">02 · Explain</div><h3>Mathematical movement workbench</h3><p>Inspect velocity vectors, group polarization and camera-clock offsets with live mathematical readouts.</p></a>
<a class="aqt-card" href="plot-playground.html"><div class="aqt-kicker">03 · Explore</div><h3>Adjust scientific plots</h3><p>Manipulate browser previews for three analytical plot families and export runnable version-pinned R examples.</p></a>
<a class="aqt-card" href="experiment-protocol-builder.html"><div class="aqt-kicker">04 · Plan</div><h3>Download synthetic protocols</h3><p>Generate a camera/tank/session planning checklist and a blank-valued CSV intake manifest.</p></a>
</div>

These are **synthetic teaching labs**, not real-video benchmark results or a fully executable R environment. See the [teaching guide](articles/scientific-teaching.html) for interpretation and related code.

## A visual laboratory

<div class="aqt-figure"><img src="hero-science.svg" alt="Stylized underwater environment showing fish silhouettes, trajectories, camera lines and scientific observation points." loading="lazy"></div>
<p class="aqt-figure-caption">Original scientific illustration. The geometry is schematic, not a measurement from a real tank.</p>

<div class="aqt-steps">
<div class="aqt-step"><strong>Start</strong><a href="articles/quickstart-five-minutes.html">Five-minute reproducible analysis</a></div>
<div class="aqt-step"><strong>Explore</strong><a href="articles/workflows-atlas.html">Complete workflow atlas</a></div>
<div class="aqt-step"><strong>Reference</strong><a href="articles/function-atlas.html">188-function main-branch guided index</a></div>
<div class="aqt-step"><strong>Research</strong><a href="articles/research-evidence-dashboard.html">Evidence and validation status</a></div>
</div>

## Reproducible first steps

```r
# Install the official versioned GitHub release (not yet on CRAN)
install.packages("remotes")
remotes::install_github("stefanosbalaskas/AquaTrajectories", ref = "v0.1.2")

library(aquaTrajectories)
x <- aqt_simulate_tracks(n_fish = 5, n_frames = 200)
aqt_plot_paths(x)
kin <- aqt_kinematics(x, max_gap_s = 0.1)
```

This simulator produces **synthetic random walks**, not biologically calibrated fish movement.

## Interactive synthetic trajectory explorer

Explore five invented trajectories in 3D, top, side and front projections. New learning controls demonstrate camera-local occlusion and ID switching: the synthetic positions remain the same while the apparent labels can change. This is a **browser-only teaching illustration**, not a real synchronized multiview recording or a validated tracking benchmark.

<div class="aqt-cta"><a href="synthetic-explorer.html">Open interactive synthetic explorer</a><a href="articles/identity-occlusion-tutorial.html">Understand occlusions and track IDs</a></div>

## Transparent evidence and reproducible figures

Before interpreting biological results, consult the [capability and validation matrix](articles/capabilities-and-validation.html), the [research evidence dashboard](articles/research-evidence-dashboard.html), and the [experiment design starter kit](articles/experiment-starter-kit.html). The dashboard links to reproducible tests and original source-evidence contracts; it does not invent benchmark accuracies.

## Explore all 22 plotting functions

The new [complete plotting-function visual atlas](articles/all-plot-functions.html) documents **all 22 `aqt_plot_*` exports**: 16 actual base-R plotting outputs reproduced from openly labeled synthetic inputs, and six separately labeled projected input previews for optional interactive `rgl` plots. Search by function name or scientific category, inspect scientific limitations, and copy the runnable calls. No projected preview is presented as a captured native `rgl` scene.

## Five complete, runnable publication figures

The [five-figure reproducible workbook](articles/five-figure-workbook.html) exercises actual native plotting functions with openly labeled **synthetic** data for feeding phases, physical XYZ error illustrations, replicated-tank occupancy, event-aligned speed, and heading roses. All five plots include source code and retain their scientific interpretation limits.

## Project and release information

- [GitHub source](https://github.com/stefanosbalaskas/AquaTrajectories)
- [Official v0.1.2 GitHub release](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.2)
- [Historical v0.1.1 Zenodo DOI: 10.5281/zenodo.24262905](https://doi.org/10.5281/zenodo.24262905) · [Download BibTeX](AquaTrajectories-v0.1.1.bib)
- [Scientific methods and validation protocols](https://github.com/stefanosbalaskas/AquaTrajectories/tree/v0.1.2/docs)
- [Function documentation](reference/index.html) · [Publication figures](articles/publication-figures.html)
