<section class="aqt-hero">
<p class="aqt-eyebrow">Open-source research software · v0.1.0 engineering preview</p>
<h1>From fish videos to scientific trajectories</h1>
<p>Analyze aquatic-animal movement with a connected R, Python and JavaScript toolkit: detections and track identities, synchronized multiview geometry, observed 2D/3D trajectories, behavioural analysis, uncertainty, and experimental workflows.</p>
<div class="aqt-cta"><a href="articles/aquaTrajectories.html">Start exploring</a><a href="reference/index.html">Browse all 155 R functions</a></div>
<div class="aqt-badges"><span>155 documented functions</span><span>2D + 3D</span><span>14 function families</span><span>Engineering-qualified preview</span></div>
</section>

<div class="aqt-note"><strong>Scientific status:</strong> this release is engineering-qualified, but biological identity, underwater metrology, fish welfare inference, empirical interval coverage and real actuator safety are **not independently certified**. See the <a href="articles/scientific-status.html">evidence and limitations</a>.</div>

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
<a class="aqt-card" href="articles/visualization-gallery.html"><div class="aqt-kicker">09 · Communicate</div><h3>Plots, figures and galleries</h3><p>Demonstration figures, publication storyboards, 3D projections and reproducible graphics.</p></a>
</div>

## A visual laboratory

<div class="aqt-figure"><img src="hero-science.svg" alt="Stylized underwater environment showing fish silhouettes, trajectories, camera lines and scientific observation points." loading="lazy"></div>
<p class="aqt-figure-caption">Original scientific illustration. The geometry is schematic, not a measurement from a real tank.</p>

<div class="aqt-steps">
<div class="aqt-step"><strong>Start</strong><a href="articles/aquaTrajectories.html">Installation and first analysis</a></div>
<div class="aqt-step"><strong>Explore</strong><a href="articles/workflows-atlas.html">Complete workflow atlas</a></div>
<div class="aqt-step"><strong>Reference</strong><a href="articles/function-atlas.html">155-function guided index</a></div>
<div class="aqt-step"><strong>Research</strong><a href="articles/research-datasets.html">Datasets and evidence</a></div>
</div>

## Reproducible first steps

```r
# Install the preview from its public source repository
install.packages("remotes")
remotes::install_github("stefanosbalaskas/AquaTrajectories", ref = "v0.1.0")

library(aquaTrajectories)
x <- aqt_simulate_tracks(n_fish = 5, n_frames = 200)
aqt_plot_paths(x)
kin <- aqt_kinematics(x, max_gap_s = 0.1)
```

This simulator produces **synthetic random walks**, not biologically calibrated fish movement.

## Five complete, runnable publication figures

The [five-figure reproducible workbook](articles/five-figure-workbook.html) exercises actual native plotting functions with openly labeled **synthetic** data for feeding phases, physical XYZ error illustrations, replicated-tank occupancy, event-aligned speed, and heading roses. All five plots include source code and retain their scientific interpretation limits.

## Project and release information

- [GitHub source](https://github.com/stefanosbalaskas/AquaTrajectories)
- [v0.1.0 engineering preview](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.0)
- [Scientific methods and validation protocols](https://github.com/stefanosbalaskas/AquaTrajectories/tree/main/docs)
- [Function documentation](reference/index.html) · [Publication figures](articles/publication-figures.html)
