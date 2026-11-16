# Scientific teaching laboratories

## Teaching with inspectable synthetic methods

The four interactive AquaTrajectories teaching labs can be used without
uploading video, installing R or supplying live-animal data. They
illustrate research workflow concepts with **invented coordinates,
boxes, labels and recording designs**. Their calculations are
deterministic for a declared seed, but **are not independent validation
studies**.

### 1. Fish detection and tracker identity

The [synthetic detection and tracking
laboratory](https://stefanosbalaskas.github.io/AquaTrajectories/scientific-tracking-lab.md)
shows labelled true boxes, predicted boxes and frame-by-frame matching.
Users manipulate missed-detection frequency, false positives, location
noise, overlap threshold and assigned ID changes. The browser computes
precision, recall and F1 from its invented boxes. Its adjacent-frame
tracker-ID change count is deliberately **not** reported as HOTA, IDF1
or another official multi-object tracking metric.

See the actual package’s [detection and tracking
functions](https://stefanosbalaskas.github.io/AquaTrajectories/reference/index.html#detection-tracking-and-annotation-validation)
and the [independent benchmark
protocol](https://stefanosbalaskas.github.io/AquaTrajectories/articles/validation-and-benchmarks.md).

### 2. Movement mathematics

The [mathematics
workbench](https://stefanosbalaskas.github.io/AquaTrajectories/math-workbench.md)
visualizes finite-difference speed, directional group polarization and
an affine camera-clock mapping. Each panel provides controlled inputs,
an algebraic expression, numerical results and direct links to released
function manuals.

The browser formulas demonstrate the concept. In real data, missing
observations, unit conversions, timestamps, valid nonzero velocities,
and independently verified physical clock markers constrain
interpretation.

### 3. Adjustable plot families

The [plot parameter
playground](https://stefanosbalaskas.github.io/AquaTrajectories/plot-playground.md)
supports three representative function families:
[`aqt_plot_paths()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_paths.md),
[`aqt_plot_ensemble2d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_ensemble2d.md)
and
[`aqt_plot_school_dynamics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_school_dynamics.md).
The live browser SVG is a **schematic simulation**, not a screenshot
produced by R. The exported R snippet calls the *actual* released v0.1.1
function using the displayed class of parameters. The [22-function plot
atlas](https://stefanosbalaskas.github.io/AquaTrajectories/articles/all-plot-functions.md)
retains 16 native base-R outputs and six labelled 2D projections of
optional `rgl` inputs.

### 4. Downloadable planning protocols

The [experiment protocol
builder](https://stefanosbalaskas.github.io/AquaTrajectories/experiment-protocol-builder.md)
creates a synthetic study-design checklist and CSV manifest for planned
tank × session × camera records. Sensitive or real acquisition fields
(video paths, SHA-256 hashes, independent timing and measured underwater
reference targets) remain empty until a researcher enters genuine
evidence.

The planner does not randomize treatments, obtain approval, create
surveyed XYZ targets, or turn synthetic observations into biological
results. See [experiment
design](https://stefanosbalaskas.github.io/AquaTrajectories/articles/experimental-design.md)
and the [camera-specific recording
planner](https://stefanosbalaskas.github.io/AquaTrajectories/articles/plan-your-experiment.md).

### Citable software and empirical limits

These lessons refer to [AquaTrajectories
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.1),
[DOI: 10.5281/zenodo.24262905](https://doi.org/10.5281/zenodo.24262905).
Laboratory teaching metrics, formula readouts, and scenario images
cannot establish fish-detection accuracy on original video,
independently reviewed identity, refractive metrology, or causal welfare
effects. Check the [evidence and validation
dashboard](https://stefanosbalaskas.github.io/AquaTrajectories/articles/research-evidence-dashboard.md)
before making scientific claims.
