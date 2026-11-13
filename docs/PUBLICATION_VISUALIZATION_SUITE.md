# AquaTrajectories 0.0.37.9000 — Publication Visualization Suite

Five **native R publication-figure functions** reuse movement metrics,
trajectory inputs and externally supplied experimental observations.
The package has not independently certified these new figure functions
until the current PR head passes native R tests and built-source R CMD check.

| Figure family | Function | Expected data |
|---|---|---|
| Feeding phases, four scenarios | `aqt_plot_feeding_states()` | `scenario,time_min,fbi,phase` |
| Calibration errors + XYZ map | `aqt_plot_calibration_comparison()` | `method,target_id,partition,truth_x/y/z,estimate_x/y/z` |
| Replicate tank occupancy | `aqt_plot_occupancy_timeseries()` | `scenario,tank_id,time_s,area_fraction` |
| Intervention-aligned speed | `aqt_plot_speed_response()` | `tank_id,time_s,speed` or `aqt_tracks` with tank ID |
| 2D angular rose / camera-frame pairs | `aqt_plot_heading_rose()` | `condition,heading_rad`; optional named raster list |

All figures are **static**, compatible with base R PDF/PNG/TIFF devices.
No ggplot2, plotly or rgl is required to draw the five new plot types.
The existing interactive XYZ explorer and rgl geometry figures remain separate.

## Reproducible five-figure workbook

The embedded example
[`inst/examples/publication_visualization_gallery.Rmd`](../inst/examples/publication_visualization_gallery.Rmd)
constructs reproducible **synthetic** research observations for five
figure families and demonstrates every new public plotting function.

With a source checkout installed in a fresh R session:

```r
library(aquaTrajectories)
install.packages("rmarkdown") # only if not already installed
rmarkdown::render(
  "inst/examples/publication_visualization_gallery.Rmd",
  output_file="AquaTrajectories_publication_figure_gallery.html"
)
```

From a **package installation** (rather than a source checkout),
copy the Rmd out of the installed library before rendering:

```r
path <- system.file("examples/publication_visualization_gallery.Rmd",
                    package="aquaTrajectories",mustWork=TRUE)
file.copy(path,"publication_visualization_gallery.Rmd",overwrite=FALSE)
rmarkdown::render("publication_visualization_gallery.Rmd")
```

## Biological and measurement boundaries

### Feeding-index panels

An externally computed/defined feeding index and **externally
assigned** phase labels must be supplied. Neither an HMM state nor an
uncertified clustering output is assumed to be feeding or stress.
The function never trains a model, classifies feeding, or computes a
scientific-significance test.

### Calibrated underwater targets

The calibration function computes the **nonnegative Euclidean XYZ
position error** per observed held-out physical target. It is not a
signed inter-fish or inter-target distance-error histogram. The input
specifies units in cm or m; coordinates are not fabricated from a
single video. Target identifiers appearing in both `fit` and
`holdout` for the same method are refused. Physical survey accuracy
and inter-dataset validation remain external responsibilities.

### Occupancy, replication and uncertainty

`area_fraction` is already-supplied coverage or occupied-area fraction
in [0,1]. It is not inferred from a fish centroid or a single point
position. Each `tank_id` must belong to one `scenario` in the figure.
Fish-frame rows are first collapsed **within** tank/time bins, followed
by across-tank means. Shaded SD/SE is descriptive across **tank
replicates**, and is suppressed when only one tank contributes. SE
bands are not automatically 95% confidence intervals.

### Swimming speed and interventions

The event onset and speed units must be supplied. For valid
`aqt_tracks`, speed can be calculated using `aqt_kinematics`, with
explicit maximum time-gap handling; otherwise supply speed measured in
a stated unit such as cm/s. Paired baseline/response results retain
individual tank means. The figure does not generate p-values or
fabricate statistical significance symbols.

### Heading rose diagrams and image conventions

The angles represent **planar XY headings** (not 3D rotations). The
researcher chooses whether headings increase clockwise or
counter-clockwise and specifies any heading-zero offset. In image
coordinates with y increasing downward, passing an uncorrected
`atan2(dy,dx)` often requires explicit clockwise interpretation.
Bins and all panel radii use the **same scale**, allowing honest
comparison across conditions. Optional raster panels are supplied by
the researcher; the plotting function does not crop, synthesize, or
retrieve original fish video frames.

## Export publication graphics

```r
grDevices::pdf("figure.pdf", width=12, height=8)
tryCatch({
  aqt_plot_heading_rose(headings, bins=16, scale="fraction")
}, finally=grDevices::dev.off())
```

For a raster image:

```r
grDevices::tiff("figure.tiff",width=3600,height=2400,
                res=300,compression="lzw")
tryCatch({
  aqt_plot_occupancy_timeseries(occupancy,band="sd")
}, finally=grDevices::dev.off())
```

Review the graphics against your journal's requirements before
submission, including axis scale, font sizes and figure captions.

## Regression / local qualification

```r
testthat::test_local(filter="publication-visualization-suite")
rcmdcheck::rcmdcheck(args=c("--no-manual"),error_on="warning")
```

The definitive gate remains the exact-commit qualified-source
`inst/python/aqt_feature_release_gate.py --mode feature_release`.
Tests with synthetic data establish software behaviour only. They
are not evidence of feeding validity, physical underwater accuracy,
independent fish identities, animal-welfare effects, or certified
hardware actuation.
