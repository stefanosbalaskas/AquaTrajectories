# Every AquaTrajectories plotting function — visual atlas

## Plot function atlas: all 22 visualizations

**Coverage:** 22 / 22 exported `aqt_plot_*` functions from the published
R API. **16 native base-R outputs are rendered through the actual
functions below**; the **six optional `rgl` visualizations use
explicitly labeled 2D projections of the same invented input**, because
a headless static documentation build cannot faithfully substitute an
interactive `rgl` scene. The documented native `rgl` call is provided
for each.

Each figure card links directly to its **reproducible example**,
**function manual**, and **version-pinned R implementation**. The
complete Rmd remains website-development source; the implementation
links correspond to the released v0.1.1 API.

All plots use **invented synthetic coordinates, synthetic study designs,
or synthetic plotting fixtures**, not real GoPro frames, biological
feeding reference labels, physical surveyed underwater targets, or
treatment effects. These examples are for software teaching. They cannot
certify fish detection, calibrated XYZ accuracy, uncertainty coverage,
animal welfare or causal inference.

Search a function or figure Scientific category All functions 3D scenes
Analysis Behaviour Diagnostics Publication Trajectories
UncertaintyRendering type Native outputs and 3D previews Actual native
plots (16) Optional rgl previews (6)**Showing 22 of 22** Clear filters

Jump to a specific plotting function (22)

[aqt_plot_paths()](#fig-plot-paths)
[aqt_plot_path3d()](#fig-plot-path3d)
[aqt_plot_calibration_comparison()](#fig-plot-calibration-comparison)
[aqt_plot_changepoints()](#fig-plot-changepoints)
[aqt_plot_ensemble2d()](#fig-plot-ensemble2d)
[aqt_plot_ensemble3d()](#fig-plot-ensemble3d)
[aqt_plot_feeding_states()](#fig-plot-feeding-states)
[aqt_plot_grid_pca()](#fig-plot-grid-pca)
[aqt_plot_heading_rose()](#fig-plot-heading-rose)
[aqt_plot_joint_scene_cloud()](#fig-plot-joint-scene-cloud)
[aqt_plot_joint_scene_cloud3d()](#fig-plot-joint-scene-cloud3d)
[aqt_plot_occupancy_timeseries()](#fig-plot-occupancy-timeseries)
[aqt_plot_reconstruction_qc()](#fig-plot-reconstruction-qc)
[aqt_plot_recurrence()](#fig-plot-recurrence)
[aqt_plot_school3d()](#fig-plot-school3d)
[aqt_plot_school_dynamics()](#fig-plot-school-dynamics)
[aqt_plot_speed_response()](#fig-plot-speed-response)
[aqt_plot_tank_changes()](#fig-plot-tank-changes)
[aqt_plot_tank_projection()](#fig-plot-tank-projection)
[aqt_plot_tank_scene3d()](#fig-plot-tank-scene3d)
[aqt_plot_trajectory_storyboard3d()](#fig-plot-trajectory-storyboard3d)
[aqt_plot_voxel3d()](#fig-plot-voxel3d)

TrajectoriesActual package output

### aqt_plot_paths()

2D trajectory plot

[View example code](#code-plot-paths)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_paths.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/geometry-viz.R)

![Actual plot rendered by aqt_plot_paths from synthetic
input](all-plot-functions_files/figure-html/gallery-plot-paths-1.png)

Direct native output from the package’s plotting function.

**Interpretation boundary:** Tracks are simulated in tank/cm units;
labels are camera-local.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_paths(toy2)
```

3D scenesProjected input preview only

### aqt_plot_path3d()

3D trajectory paths

[View example code](#code-plot-path3d)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_path3d.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/geometry-viz.R)

![Clearly labeled two-dimensional input projection for optional rgl
function
aqt_plot_path3d](all-plot-functions_files/figure-html/gallery-plot-path3d-1.png)

Native 3D function: `aqt_plot_path3d(toy3)`. The displayed figure is
only an orthographic input preview; `rgl` is required to view the actual
plot. **Optional native rgl function:** `aqt_plot_path3d(toy3)`
(requires `rgl` and physical XYZ semantics where applicable). This page
does **not** pretend the above projection is its native output.

**Interpretation boundary:** Invented XYZ coordinates do not establish
underwater reconstruction accuracy.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_path3d(toy3)
```

PublicationActual package output

### aqt_plot_calibration_comparison()

Held-out XYZ calibration comparison

[View example code](#code-plot-calibration-comparison)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_calibration_comparison.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/publication-calibration-comparison.R)

![Actual plot rendered by aqt_plot_calibration_comparison from synthetic
input](all-plot-functions_files/figure-html/gallery-plot-calibration-comparison-1.png)

Native multi-panel calibration figure based on synthetic *held-out*
reference coordinates.

**Interpretation boundary:** Reference positions are fabricated for
teaching; no real calibration is certified.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_calibration_comparison(calibration, units = 'cm')
```

BehaviourActual package output

### aqt_plot_changepoints()

Change-point diagnostics

[View example code](#code-plot-changepoints)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_changepoints.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/fish-changepoints.R)

![Actual plot rendered by aqt_plot_changepoints from synthetic
input](all-plot-functions_files/figure-html/gallery-plot-changepoints-1.png)

Native plot from
[`aqt_state_changepoint()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_state_changepoint.md)
on an invented signal.

**Interpretation boundary:** Descriptive mean changes are not
automatically biological state changes.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_changepoints(cp_fit)
```

UncertaintyActual package output

### aqt_plot_ensemble2d()

2D measurement-error scenarios

[View example code](#code-plot-ensemble2d)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_ensemble2d.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/sensitivity-viz.R)

![Actual plot rendered by aqt_plot_ensemble2d from synthetic
input](all-plot-functions_files/figure-html/gallery-plot-ensemble2d-1.png)

Native conditional scenario paths with original trajectory overlay.

**Interpretation boundary:** Not a calibrated predictive interval,
posterior or independent measurement.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_ensemble2d(ensemble2, "S01", "SIM", "fish1", n_draws = 20L)
```

3D scenesProjected input preview only

### aqt_plot_ensemble3d()

3D measurement-error scenarios

[View example code](#code-plot-ensemble3d)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_ensemble3d.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/sensitivity-viz.R)

![Clearly labeled two-dimensional input projection for optional rgl
function
aqt_plot_ensemble3d](all-plot-functions_files/figure-html/gallery-plot-ensemble3d-1.png)

Native 3D function:
`aqt_plot_ensemble3d(ensemble3, 'S01', 'SIM', 'fish1')`. Preview shows
just one scenario as a 2D projection, not the rgl scene. **Optional
native rgl function:**
`aqt_plot_ensemble3d(ensemble3, 'S01', 'SIM', 'fish1')` (requires `rgl`
and physical XYZ semantics where applicable). This page does **not**
pretend the above projection is its native output.

**Interpretation boundary:** Conditional noise assumptions are not
independently validated uncertainty coverage.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_ensemble3d(ensemble3, 'S01', 'SIM', 'fish1')
```

PublicationActual package output

### aqt_plot_feeding_states()

Descriptive feeding-index phases

[View example code](#code-plot-feeding-states)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_feeding_states.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/publication-feeding-states.R)

![Actual plot rendered by aqt_plot_feeding_states from synthetic
input](all-plot-functions_files/figure-html/gallery-plot-feeding-states-1.png)

Native four-condition publication figure with supplied numerical index
and labels.

**Interpretation boundary:** Both index and phase categories are
artificially supplied; not inferred feeding truth.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_feeding_states(feeding, event_time_min = 0)
```

AnalysisActual package output

### aqt_plot_grid_pca()

Dense-grid trajectory PCA

[View example code](#code-plot-grid-pca)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_grid_pca.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/trajectory-grid-pca.R)

![Actual plot rendered by aqt_plot_grid_pca from synthetic
input](all-plot-functions_files/figure-html/gallery-plot-grid-pca-1.png)

Native finite-grid PCA mode display for registered synthetic paths.

**Interpretation boundary:** Not sparse FPCA or biological confidence
bands.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_grid_pca(pca_fit, component = 1L)
```

PublicationActual package output

### aqt_plot_heading_rose()

Circular heading rose

[View example code](#code-plot-heading-rose)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_heading_rose.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/publication-heading-rose.R)

![Actual plot rendered by aqt_plot_heading_rose from synthetic
input](all-plot-functions_files/figure-html/gallery-plot-heading-rose-1.png)

Native angular histogram with explicit mathematical direction
convention.

**Interpretation boundary:** 2D projected headings, not measured full 3D
animal orientation.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_heading_rose(headings, bins = 18L)
```

UncertaintyActual package output

### aqt_plot_joint_scene_cloud()

Joint uncertainty scenario cloud

[View example code](#code-plot-joint-scene-cloud)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_joint_scene_cloud.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/joint-scene-cloud.R)

![Actual plot rendered by aqt_plot_joint_scene_cloud from synthetic
input](all-plot-functions_files/figure-html/gallery-plot-joint-scene-cloud-1.png)

Native projected scenario cloud on a clearly labeled plot-only synthetic
fixture.

**Interpretation boundary:** A multimodal identity cloud cannot be
reduced to a calibrated Gaussian ellipse.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_joint_scene_cloud(cloud, plane = 'xy')
```

3D scenesProjected input preview only

### aqt_plot_joint_scene_cloud3d()

3D joint uncertainty samples

[View example code](#code-plot-joint-scene-cloud3d)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_joint_scene_cloud3d.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/joint-scene-cloud.R)

![Clearly labeled two-dimensional input projection for optional rgl
function
aqt_plot_joint_scene_cloud3d](all-plot-functions_files/figure-html/gallery-plot-joint-scene-cloud3d-1.png)

Native 3D function: `aqt_plot_joint_scene_cloud3d(cloud)`. This is a 2D
projection of the fixture, not its native rgl output. **Optional native
rgl function:** `aqt_plot_joint_scene_cloud3d(cloud)` (requires `rgl`
and physical XYZ semantics where applicable). This page does **not**
pretend the above projection is its native output.

**Interpretation boundary:** No real optical errors or empirical
posterior distributions are supplied.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_joint_scene_cloud3d(cloud)
```

PublicationActual package output

### aqt_plot_occupancy_timeseries()

Tank occupancy time series

[View example code](#code-plot-occupancy-timeseries)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_occupancy_timeseries.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/publication-occupancy-timeseries.R)

![Actual plot rendered by aqt_plot_occupancy_timeseries from synthetic
input](all-plot-functions_files/figure-html/gallery-plot-occupancy-timeseries-1.png)

Native plot aggregating invented area fractions across tank units.

**Interpretation boundary:** Bands are descriptive between-tank SD, not
inferential confidence intervals.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_occupancy_timeseries(occupancy, time_bin_s = 60,
                                 band = 'sd')
```

DiagnosticsActual package output

### aqt_plot_reconstruction_qc()

Stereo reconstruction QC

[View example code](#code-plot-reconstruction-qc)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_reconstruction_qc.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/voxel-quality.R)

![Actual plot rendered by aqt_plot_reconstruction_qc from synthetic
input](all-plot-functions_files/figure-html/gallery-plot-reconstruction-qc-1.png)

Native two-panel RMSE/time-skew distribution from synthetic QC columns.

**Interpretation boundary:** Small reprojection error does not prove
underwater positional accuracy.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_reconstruction_qc(qc_tracks)
```

AnalysisActual package output

### aqt_plot_recurrence()

Trajectory recurrence matrix

[View example code](#code-plot-recurrence)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_recurrence.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/trajectory-shape.R)

![Actual plot rendered by aqt_plot_recurrence from synthetic
input](all-plot-functions_files/figure-html/gallery-plot-recurrence-1.png)

Native recurrence image for the observed-position proximity rule.

**Interpretation boundary:** This is not inferred animal stereotypy or
an ethological diagnosis.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_recurrence(recurrence)
```

3D scenesProjected input preview only

### aqt_plot_school3d()

Fish-school spatial snapshot

[View example code](#code-plot-school3d)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_school3d.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/school-spatial-viz.R)

![Clearly labeled two-dimensional input projection for optional rgl
function
aqt_plot_school3d](all-plot-functions_files/figure-html/gallery-plot-school3d-1.png)

Native 3D function: `aqt_plot_school3d(toy3, 'S01', 'SIM', 5)`. The
thumbnail is an input projection only. **Optional native rgl function:**
`aqt_plot_school3d(toy3, 'S01', 'SIM', 5)` (requires `rgl` and physical
XYZ semantics where applicable). This page does **not** pretend the
above projection is its native output.

**Interpretation boundary:** Camera-scoped labels are not independently
established identities.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_school3d(toy3, 'S01', 'SIM', 5)
```

AnalysisActual package output

### aqt_plot_school_dynamics()

School geometry over time

[View example code](#code-plot-school-dynamics)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_school_dynamics.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/school-spatial-viz.R)

![Actual plot rendered by aqt_plot_school_dynamics from synthetic
input](all-plot-functions_files/figure-html/gallery-plot-school-dynamics-1.png)

Native school-radius or distance trend computed from simultaneously
observed simulated fish.

**Interpretation boundary:** Movement group structure can be sensitive
to observed fish count and tracking loss.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_school_dynamics(group_summary, "S01", "SIM")
```

PublicationActual package output

### aqt_plot_speed_response()

Event-aligned speed changes

[View example code](#code-plot-speed-response)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_speed_response.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/publication-speed-response.R)

![Actual plot rendered by aqt_plot_speed_response from synthetic
input](all-plot-functions_files/figure-html/gallery-plot-speed-response-1.png)

Native two-panel tank-aggregated speed figure with synthetic tank
identifiers.

**Interpretation boundary:** Illustrative speed and event times are not
real treatment outcomes.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_speed_response(speed_data, event_time_s = 0,
  baseline_s = c(-30, 0), response_s = c(0, 30),
  speed_unit = 'cm/s', time_bin_s = 2)
```

AnalysisActual package output

### aqt_plot_tank_changes()

Tank-level before/after comparisons

[View example code](#code-plot-tank-changes)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_tank_changes.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/event-visualization.R)

![Actual plot rendered by aqt_plot_tank_changes from synthetic
input](all-plot-functions_files/figure-html/gallery-plot-tank-changes-1.png)

Native paired tank trajectories, preserving the experiment’s unit of
replication.

**Interpretation boundary:** Independent tank labels are invented and do
not create causal identification.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_tank_changes(tank_fit)
```

3D scenesActual package output

### aqt_plot_tank_projection()

Physical XYZ scene projection

[View example code](#code-plot-tank-projection)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_tank_projection.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/tank-scenes.R)

![Actual plot rendered by aqt_plot_tank_projection from synthetic
input](all-plot-functions_files/figure-html/gallery-plot-tank-projection-1.png)

Native orthographic projection derived from complete synthetic XYZ
input.

**Interpretation boundary:** An existing depth coordinate is required;
the plot does not infer one from video.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_tank_projection(scene3, plane = 'xy')
```

3D scenesProjected input preview only

### aqt_plot_tank_scene3d()

3D tank scene with movement tails

[View example code](#code-plot-tank-scene3d)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_tank_scene3d.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/tank-scenes.R)

![Clearly labeled two-dimensional input projection for optional rgl
function
aqt_plot_tank_scene3d](all-plot-functions_files/figure-html/gallery-plot-tank-scene3d-1.png)

Native 3D function: `aqt_plot_tank_scene3d(scene3)`; projected teaching
preview is not an actual rgl scene. **Optional native rgl function:**
`aqt_plot_tank_scene3d(scene3)` (requires `rgl` and physical XYZ
semantics where applicable). This page does **not** pretend the above
projection is its native output.

**Interpretation boundary:** Real physical XYZ and independently
measured optics are still necessary.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_tank_scene3d(scene3)
```

3D scenesActual package output

### aqt_plot_trajectory_storyboard3d()

Four-frame 3D storyboard

[View example code](#code-plot-trajectory-storyboard3d)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_trajectory_storyboard3d.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/trajectory-storyboard3d.R)

![Actual plot rendered by aqt_plot_trajectory_storyboard3d from
synthetic
input](all-plot-functions_files/figure-html/gallery-plot-trajectory-storyboard3d-1.png)

Native four-panel axonometric base-R figure; uses the supplied synthetic
XYZ.

**Interpretation boundary:** Recency bands summarize observed segments
only; unobserved travel is not estimated.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_trajectory_storyboard3d(one3,
  times_s = c(2, 4, 6, 8),
  recent_s = 1, max_gap_s = .11, max_age_s = .11)
```

3D scenesProjected input preview only

### aqt_plot_voxel3d()

3D voxel occupancy

[View example code](#code-plot-voxel3d)[Function
manual](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_voxel3d.md)[Source
in
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/school-spatial-viz.R)

![Clearly labeled two-dimensional input projection for optional rgl
function
aqt_plot_voxel3d](all-plot-functions_files/figure-html/gallery-plot-voxel3d-1.png)

Native 3D function: `aqt_plot_voxel3d(voxels)`. Projection shows
synthetic observed sample frequencies, not the actual optional rgl
output. **Optional native rgl function:** `aqt_plot_voxel3d(voxels)`
(requires `rgl` and physical XYZ semantics where applicable). This page
does **not** pretend the above projection is its native output.

**Interpretation boundary:** Voxels represent counted sample points, not
inferred continuous residence time.

Reproduce this example

``` r

# Run the fixture setup from this page's source Rmd first.
aqt_plot_voxel3d(voxels)
```

### Reproducibility and limitations

The **complete synthetic fixture setup**, all 22 plot calls and the six
projected-preview routines are included in this website article’s
source. Follow the individual function reference links for argument
specifications. Only the 16 plots marked **Actual package output** are
screenshots generated by invoking their own `aqt_plot_*` R function in
the website build. The other six demonstrate only the input geometry and
should be opened locally with optional `rgl` for native 3D.

Website-development source (moving main branch): [plot function atlas
Rmd on
GitHub](https://github.com/stefanosbalaskas/AquaTrajectories/blob/main/vignettes/articles/all-plot-functions.Rmd).
For a shorter introduction, see the [five-figure
workbook](https://stefanosbalaskas.github.io/AquaTrajectories/articles/five-figure-workbook.md),
the [interactive synthetic teaching
lab](https://stefanosbalaskas.github.io/AquaTrajectories/synthetic-explorer.md),
and the [capabilities and validation
matrix](https://stefanosbalaskas.github.io/AquaTrajectories/articles/capabilities-and-validation.md).
