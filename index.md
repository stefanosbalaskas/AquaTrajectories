# From fish videos to scientific trajectories

Open-source research software · v0.1.0 engineering preview

Analyze aquatic-animal movement with a connected R, Python and
JavaScript toolkit: detections and track identities, synchronized
multiview geometry, observed 2D/3D trajectories, behavioural analysis,
uncertainty, and experimental workflows.

[Start
exploring](https://stefanosbalaskas.github.io/AquaTrajectories/articles/aquaTrajectories.md)[Browse
all 155 R
functions](https://stefanosbalaskas.github.io/AquaTrajectories/reference/index.md)

155 documented functions2D + 3D14 function familiesEngineering-qualified
preview

**Scientific status:** this release is engineering-qualified, but
biological identity, underwater metrology, fish welfare inference,
empirical interval coverage and real actuator safety are **not
independently certified**. See the [evidence and
limitations](https://stefanosbalaskas.github.io/AquaTrajectories/articles/scientific-status.md).

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

[](https://stefanosbalaskas.github.io/AquaTrajectories/articles/visualization-gallery.md)

09 · Communicate

### Plots, figures and galleries

Demonstration figures, publication storyboards, 3D projections and
reproducible graphics.

## A visual laboratory

![Stylized underwater environment showing fish silhouettes,
trajectories, camera lines and scientific observation
points.](hero-science.svg)

Original scientific illustration. The geometry is schematic, not a
measurement from a real tank.

**Start**[Installation and first
analysis](https://stefanosbalaskas.github.io/AquaTrajectories/articles/aquaTrajectories.md)

**Explore**[Complete workflow
atlas](https://stefanosbalaskas.github.io/AquaTrajectories/articles/workflows-atlas.md)

**Reference**[155-function guided
index](https://stefanosbalaskas.github.io/AquaTrajectories/articles/function-atlas.md)

**Research**[Datasets and
evidence](https://stefanosbalaskas.github.io/AquaTrajectories/articles/research-datasets.md)

## Reproducible first steps

``` r

# Install the preview from its public source repository
install.packages("remotes")
remotes::install_github("stefanosbalaskas/AquaTrajectories", ref = "v0.1.0")

library(aquaTrajectories)
x <- aqt_simulate_tracks(n_fish = 5, n_frames = 200)
aqt_plot_paths(x)
kin <- aqt_kinematics(x, max_gap_s = 0.1)
```

This simulator produces **synthetic random walks**, not biologically
calibrated fish movement.

## Interactive synthetic trajectory explorer

Explore five invented trajectories in synchronized 3D, top, side and
front projections with a frame scrubber, playback and individual track
toggles. This is a **browser-only teaching demonstration**, not the
actual multiview research explorer or a real animal observation.

[Open interactive synthetic
explorer](https://stefanosbalaskas.github.io/AquaTrajectories/synthetic-explorer.md)

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
- [v0.1.0 engineering
  preview](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.0)
- [Scientific methods and validation
  protocols](https://github.com/stefanosbalaskas/AquaTrajectories/tree/main/docs)
- [Function
  documentation](https://stefanosbalaskas.github.io/AquaTrajectories/reference/index.md)
  · [Publication
  figures](https://stefanosbalaskas.github.io/AquaTrajectories/articles/publication-figures.md)
