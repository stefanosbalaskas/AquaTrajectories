# Publication Visualization 2.0: reviewed figures and provenance

Visualization 2.0 converts supplied 2D/3D trajectories into four
journal-oriented plots with exact source-row and QC policy linkage. The
example dataset below is **synthetic**, not measured fish movement.

## Journal starting-point presets

The returned journal-style widths and raster DPI are reproducible
technical defaults, not a promise of compliance with a named publisher.

~{r setup, include=FALSE} library(aquaTrajectories)
knitr::opts_chunk\$set(echo=TRUE,fig.width=8,fig.height=5,
fig.align=“center”,warning=FALSE,message=FALSE) ~

~{r presets} aqt_viz2_presets() ~

## One reviewed data source, four native figures

The fish observations include a deliberately missing position and a
source-frame discontinuity. Neither can form a movement line segment.

~{r input} time \<- 0:12 rows \<- do.call(rbind,lapply(1:3,function(i) {
x \<- .5*i + .2*time + .15*sin(time/2+i) y \<- i + .35*cos(time/2+i)
observed \<- !(i==2L & time==5L)
data.frame(session_id=“SYNTHETIC”,camera_id=“TOP”,
track_id=paste0(“fish”,i),frame_id=time+as.integer(time\>=8),
time_s=time,x=ifelse(observed,x,NA_real\_),
y=ifelse(observed,y,NA_real\_),observed=observed,
source_row=paste0(i,“-”,time)) })) tracks \<-
aqt_tracks(rows,units=“cm”,coordinate_system=“tank”) qc \<-
aqt_qc2_report(tracks,gap_limits_s=1.01,speed_limits=2)
stopifnot(nrow(qc\$lineage)==nrow(rows)) ~

### QC-eligible spatial path segments

~{r viz2-paths, fig.alt=“Native observed-position trajectories, broken
at missing and excluded steps”} paths \<-
aqt_viz2_spec(qc,figure=“paths”,policy_id=“QC001”,
preset=“journal_double”) aqt_viz2_draw(paths) ~

### Only eligible speed measurements

~{r viz2-speed, fig.alt=“Observed speed from only valid source steps”}
speed \<- aqt_viz2_spec(qc,figure=“speed”,policy_id=“QC001”)
aqt_viz2_draw(speed) ~

### Source-row coverage

~{r viz2-coverage, fig.alt=“Exact eligible, excluded and nonestimable
source-row coverage”} coverage \<-
aqt_viz2_spec(qc,figure=“qc_coverage”, policy_id=“QC001”)
aqt_viz2_draw(coverage) ~

### Complete QC reason classification

~{r viz2-reasons, fig.alt=“QC decision reason frequency for original
rows”} reasons \<- aqt_viz2_spec(qc,figure=“qc_reasons”,
policy_id=“QC001”) aqt_viz2_draw(reasons) ~

## Transactional source-linked export

The following code creates both vector and raster artwork, plus the
input row, eligible-movement and full QC decision evidence. It refuses
to overwrite an existing directory.

``` r

aqt_viz2_export(paths, "manuscript_figure_1",
                formats=c("pdf","svg","png","tiff"))
stopifnot(aqt_viz2_verify("manuscript_figure_1"))
```

If the original source file, sealed specification or output file is
modified without a new scientific audit, validation fails. All 22
existing public native plotting functions are documented in the
[complete public plotting
gallery](https://stefanosbalaskas.github.io/AquaTrajectories/articles/all-plot-functions.md).

For scientific and publisher limitations, consult the [Publication
Visualization 2.0
methods](https://github.com/stefanosbalaskas/AquaTrajectories/blob/main/docs/PUBLICATION_VISUALIZATION_2_0.md).
