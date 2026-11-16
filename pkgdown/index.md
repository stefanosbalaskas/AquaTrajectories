<section class="aqt-hero">
<p class="aqt-eyebrow">Open-source research software · official v0.1.1 release</p>
<h1>From aquatic observations to reproducible movement science</h1>
<p>Track, reconstruct, analyze and visualize aquatic-animal trajectories with R, Python and browser tools. Start with documented synthetic examples, then supply independent annotations, camera calibration and real recording metadata for scientific measurements.</p>
<div class="aqt-cta"><a href="articles/quickstart-five-minutes.html">Run a five-minute example</a><a href="synthetic-explorer.html">Open interactive lab</a><a href="articles/plan-your-experiment.html">Plan your experiment</a></div>
<div class="aqt-badges"><span>155 documented R functions</span><span>14 reference categories</span><span>Official GitHub release v0.1.1</span><span>Zenodo archived</span></div>
</section>

<div class="aqt-note"><strong>Published software:</strong> <a href="https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.1">AquaTrajectories v0.1.1</a> is a public GitHub release, permanently archived as <a href="https://doi.org/10.5281/zenodo.24262905">10.5281/zenodo.24262905</a> on Zenodo. <a href="https://zenodo.org/badge/DOI/10.5281/zenodo.24262905.svg"><img src="https://zenodo.org/badge/DOI/10.5281/zenodo.24262905.svg" alt="Zenodo DOI 10.5281/zenodo.24262905" loading="lazy"></a> CRAN qualification is in progress; this package is not yet published on CRAN.</div>

<div class="aqt-note"><strong>Scientific status:</strong> this release is engineering-qualified, but biological identity, underwater metrology, fish welfare inference, empirical interval coverage and real actuator safety are **not independently certified**. See the <a href="articles/scientific-status.html">evidence and limitations</a>.</div>


## Choose your path

<div class="aqt-cardgrid aqt-entrygrid">
<a class="aqt-card" href="articles/quickstart-five-minutes.html"><div class="aqt-kicker">New to R</div><h3>Try a complete analysis</h3><p>Five minutes: synthetic tracks → movement → event alignment → CSV exports. Confirm expected row counts.</p></a>
<a class="aqt-card" href="articles/video-to-results.html"><div class="aqt-kicker">Working with footage</div><h3>Plan video → results</h3><p>Original PTS, externally trained detector, reviewable IDs, camera geometry, explicit scientific gates.</p></a>
<a class="aqt-card" href="articles/plan-your-experiment.html"><div class="aqt-kicker">Planning an experiment</div><h3>Choose your recording setup</h3><p>One camera, two cameras, or existing footage: match the workflow to the evidence your study can support.</p></a>
<a class="aqt-card" href="synthetic-explorer.html"><div class="aqt-kicker">Interactive laboratory</div><h3>Explore fish tracking visually</h3><p>Five invented tracks, two camera projections, occlusions, identity switches, event markers and exportable teaching outputs.</p></a>
</div>

<div class="aqt-statusbar" role="group" aria-label="Current release and scientific evidence">
  <div><strong>Released</strong><span><a href="https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.1">v0.1.1</a> · MIT-licensed source</span></div>
  <div><strong>Citable</strong><span><a href="https://doi.org/10.5281/zenodo.24262905">Zenodo DOI</a> · <a href="AquaTrajectories-v0.1.1.bib" download>BibTeX</a></span></div>
  <div><strong>Scientific validity</strong><span>Software contracts tested; <a href="articles/capabilities-and-validation.html">independent biological validation pending</a></span></div>
</div>

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

## Scientific teaching: four interactive laboratories

Explore deterministic examples that separate **what software computes** from **what real biological observations establish**. Each exercise runs locally in the browser, uses invented inputs, and links to the published v0.1.1 R documentation.

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
<div class="aqt-step"><strong>Reference</strong><a href="articles/function-atlas.html">155-function guided index</a></div>
<div class="aqt-step"><strong>Research</strong><a href="articles/research-evidence-dashboard.html">Evidence and validation status</a></div>
</div>

## Reproducible first steps

```r
# Install the official versioned GitHub release (not yet on CRAN)
install.packages("remotes")
remotes::install_github("stefanosbalaskas/AquaTrajectories", ref = "v0.1.1")

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
- [Official v0.1.1 GitHub release](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.1)
- [Version-specific Zenodo DOI: 10.5281/zenodo.24262905](https://doi.org/10.5281/zenodo.24262905) · [Download BibTeX](AquaTrajectories-v0.1.1.bib)
- [Scientific methods and validation protocols](https://github.com/stefanosbalaskas/AquaTrajectories/tree/v0.1.1/docs)
- [Function documentation](reference/index.html) · [Publication figures](articles/publication-figures.html)
