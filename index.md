# From aquatic observations to reproducible movement science

Open-source research software · official v0.1.1 release

Track, reconstruct, analyze and visualize aquatic-animal trajectories
with R, Python and browser tools. Start with documented synthetic
examples, then supply independent annotations, camera calibration and
real recording metadata for scientific measurements.

[Run a five-minute
example](https://stefanosbalaskas.github.io/AquaTrajectories/articles/quickstart-five-minutes.md)[Open
interactive
lab](https://stefanosbalaskas.github.io/AquaTrajectories/synthetic-explorer.md)[Plan
your
experiment](https://stefanosbalaskas.github.io/AquaTrajectories/articles/plan-your-experiment.md)

155 documented R functions14 reference categoriesOfficial GitHub release
v0.1.1Zenodo archived

**Published software:** [AquaTrajectories
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.1)
is a public GitHub release, permanently archived as
[10.5281/zenodo.24262905](https://doi.org/10.5281/zenodo.24262905) on
Zenodo. [![Zenodo DOI
10.5281/zenodo.24262905](https://zenodo.org/badge/DOI/10.5281/zenodo.24262905.svg)](https://zenodo.org/badge/DOI/10.5281/zenodo.24262905.svg)
CRAN qualification is in progress; this package is not yet published on
CRAN.

**Scientific status:** this release is engineering-qualified, but
biological identity, underwater metrology, fish welfare inference,
empirical interval coverage and real actuator safety are **not
independently certified**. See the [evidence and
limitations](https://stefanosbalaskas.github.io/AquaTrajectories/articles/scientific-status.md).

## Choose your path

[](https://stefanosbalaskas.github.io/AquaTrajectories/articles/quickstart-five-minutes.md)

New to R

### Try a complete analysis

Five minutes: synthetic tracks → movement → event alignment → CSV
exports. Confirm expected row counts.

[](https://stefanosbalaskas.github.io/AquaTrajectories/articles/video-to-results.md)

Working with footage

### Plan video → results

Original PTS, externally trained detector, reviewable IDs, camera
geometry, explicit scientific gates.

[](https://stefanosbalaskas.github.io/AquaTrajectories/articles/plan-your-experiment.md)

Planning an experiment

### Choose your recording setup

One camera, two cameras, or existing footage: match the workflow to the
evidence your study can support.

[](https://stefanosbalaskas.github.io/AquaTrajectories/synthetic-explorer.md)

Interactive laboratory

### Explore fish tracking visually

Five invented tracks, two camera projections, occlusions, identity
switches, event markers and exportable teaching outputs.

**Released**[v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.1)
· MIT-licensed source

**Citable**[Zenodo DOI](https://doi.org/10.5281/zenodo.24262905) ·
[BibTeX](https://stefanosbalaskas.github.io/AquaTrajectories/AquaTrajectories-v0.1.1.bib)

**Scientific validity**Software contracts tested; [independent
biological validation
pending](https://stefanosbalaskas.github.io/AquaTrajectories/articles/capabilities-and-validation.md)

## Discover the research workflows

![Conceptual workflow: videos and metadata move through detection,
tracking, synchronized multiview geometry, uncertainty, behavioural
analysis and scientific review.](workflow.svg)

Conceptual software workflow, not an empirical performance result.

[](https://stefanosbalaskas.github.io/AquaTrajectories/articles/video-tracking.md)

01 · Acquire

### Video tracking and identities

GoPro inputs, video PTS, YOLO/ByteTrack integration, tracker exports and
manual annotation.

[](https://stefanosbalaskas.github.io/AquaTrajectories/articles/multiview-3d.md)

02 · Reconstruct

### Multiview 3D and refraction

Stereo rigs, clock diagnostics, Brown correction, air–glass–water optics
and geometric correspondence.

[](https://stefanosbalaskas.github.io/AquaTrajectories/articles/validation-and-benchmarks.md)

03 · Validate

### Scientific benchmarks

Detection F1, IDF1, holdout targets, physical XYZ error and source-truth
provenance.

[](https://stefanosbalaskas.github.io/AquaTrajectories/articles/movement-and-schooling.md)

04 · Characterize

### Movement and schooling

Speed, paths, spatial occupancy, school geometry, 3D scenes and
trajectory recurrence.

[](https://stefanosbalaskas.github.io/AquaTrajectories/articles/behavioural-models.md)

05 · Model

### Behaviour and longitudinal models

Changepoints, Gaussian HMMs, FPCA, functional curves and nested
tank/fish models.

[](https://stefanosbalaskas.github.io/AquaTrajectories/articles/uncertainty.md)

06 · Question

### Uncertainty-aware inference

Pixel, optical, identity and trajectory perturbations, with explicit
model assumptions.

[](https://stefanosbalaskas.github.io/AquaTrajectories/articles/experimental-design.md)

07 · Experiment

### Events and independent tanks

Event alignment, tank-replicated summaries and defensible inferential
units.

[](https://stefanosbalaskas.github.io/AquaTrajectories/articles/aci-workflows.md)

08 · Interact

### Animal–Computer Interaction

Telemetry, choices, access inequality and bounded device-control
research protocols.

[](https://stefanosbalaskas.github.io/AquaTrajectories/articles/all-plot-functions.md)

09 · Communicate

### All 22 plotting functions

Demonstration figures, publication storyboards, 3D projections and
reproducible graphics.

## Choose your camera configuration

The [experiment planning
guide](https://stefanosbalaskas.github.io/AquaTrajectories/articles/plan-your-experiment.md)
provides separate paths for [one-camera 2D
tracking](https://stefanosbalaskas.github.io/AquaTrajectories/articles/plan-your-experiment.html#one-camera),
[two-camera 3D
research](https://stefanosbalaskas.github.io/AquaTrajectories/articles/plan-your-experiment.html#two-cameras),
and [existing
recordings](https://stefanosbalaskas.github.io/AquaTrajectories/articles/plan-your-experiment.html#existing-recordings).
Camera count alone does not establish physically calibrated XYZ or
biological identity.

## A visual laboratory

![Stylized underwater environment showing fish silhouettes,
trajectories, camera lines and scientific observation
points.](hero-science.svg)

Original scientific illustration. The geometry is schematic, not a
measurement from a real tank.

**Start**[Five-minute reproducible
analysis](https://stefanosbalaskas.github.io/AquaTrajectories/articles/quickstart-five-minutes.md)

**Explore**[Complete workflow
atlas](https://stefanosbalaskas.github.io/AquaTrajectories/articles/workflows-atlas.md)

**Reference**[155-function guided
index](https://stefanosbalaskas.github.io/AquaTrajectories/articles/function-atlas.md)

**Research**[Evidence and validation
status](https://stefanosbalaskas.github.io/AquaTrajectories/articles/research-evidence-dashboard.md)

## Reproducible first steps

``` r

# Install the official versioned GitHub release (not yet on CRAN)
install.packages("remotes")
remotes::install_github("stefanosbalaskas/AquaTrajectories", ref = "v0.1.1")

library(aquaTrajectories)
x <- aqt_simulate_tracks(n_fish = 5, n_frames = 200)
aqt_plot_paths(x)
kin <- aqt_kinematics(x, max_gap_s = 0.1)
```

This simulator produces **synthetic random walks**, not biologically
calibrated fish movement.

## Interactive synthetic trajectory explorer

Explore five invented trajectories in 3D, top, side and front
projections. New learning controls demonstrate camera-local occlusion
and ID switching: the synthetic positions remain the same while the
apparent labels can change. This is a **browser-only teaching
illustration**, not a real synchronized multiview recording or a
validated tracking benchmark.

[Open interactive synthetic
explorer](https://stefanosbalaskas.github.io/AquaTrajectories/synthetic-explorer.md)[Understand
occlusions and track
IDs](https://stefanosbalaskas.github.io/AquaTrajectories/articles/identity-occlusion-tutorial.md)

## Transparent evidence and reproducible figures

Before interpreting biological results, consult the [capability and
validation
matrix](https://stefanosbalaskas.github.io/AquaTrajectories/articles/capabilities-and-validation.md),
the [research evidence
dashboard](https://stefanosbalaskas.github.io/AquaTrajectories/articles/research-evidence-dashboard.md),
and the [experiment design starter
kit](https://stefanosbalaskas.github.io/AquaTrajectories/articles/experiment-starter-kit.md).
The dashboard links to reproducible tests and original source-evidence
contracts; it does not invent benchmark accuracies.

## Explore all 22 plotting functions

The new [complete plotting-function visual
atlas](https://stefanosbalaskas.github.io/AquaTrajectories/articles/all-plot-functions.md)
documents **all 22 `aqt_plot_*` exports**: 16 actual base-R plotting
outputs reproduced from openly labeled synthetic inputs, and six
separately labeled projected input previews for optional interactive
`rgl` plots. Search by function name or scientific category, inspect
scientific limitations, and copy the runnable calls. No projected
preview is presented as a captured native `rgl` scene.

## Five complete, runnable publication figures

The [five-figure reproducible
workbook](https://stefanosbalaskas.github.io/AquaTrajectories/articles/five-figure-workbook.md)
exercises actual native plotting functions with openly labeled
**synthetic** data for feeding phases, physical XYZ error illustrations,
replicated-tank occupancy, event-aligned speed, and heading roses. All
five plots include source code and retain their scientific
interpretation limits.

## Project and release information

- [GitHub source](https://github.com/stefanosbalaskas/AquaTrajectories)
- [Official v0.1.1 GitHub
  release](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.1)
- [Version-specific Zenodo DOI:
  10.5281/zenodo.24262905](https://doi.org/10.5281/zenodo.24262905) ·
  [Download
  BibTeX](https://stefanosbalaskas.github.io/AquaTrajectories/AquaTrajectories-v0.1.1.bib)
- [Scientific methods and validation
  protocols](https://github.com/stefanosbalaskas/AquaTrajectories/tree/v0.1.1/docs)
- [Function
  documentation](https://stefanosbalaskas.github.io/AquaTrajectories/reference/index.md)
  · [Publication
  figures](https://stefanosbalaskas.github.io/AquaTrajectories/articles/publication-figures.md)
