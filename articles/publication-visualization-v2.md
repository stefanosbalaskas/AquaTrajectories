# Publication Visualization 2.0: reviewed figures and provenance

Visualization 2.0 converts supplied 2D/3D trajectories into four
journal-oriented plots with exact source-row and QC policy linkage. The
example dataset below is **synthetic**, not measured fish movement. The
four figures below are rendered by the package during the website build;
the full executable R Markdown source is linked above.

## Journal starting-point presets

The returned journal-style widths and raster DPI are reproducible
technical defaults, not a promise of compliance with a named publisher.

| preset         | width_in | height_in | dpi | pointsize |
|:---------------|---------:|----------:|----:|----------:|
| journal_single |      3.5 |      3.30 | 600 |         9 |
| journal_double |      7.2 |      4.80 | 300 |        12 |
| manuscript     |      6.8 |      4.80 | 300 |        11 |
| presentation   |     12.0 |      6.75 | 150 |        16 |

Reproducible figure-size and raster-resolution presets {.table}

## One reviewed data source, four native figures

The fish observations include a deliberately missing position and a
source-frame discontinuity. Neither can form a movement line segment.

### QC-eligible spatial path segments

![Native observed-position trajectories, broken at missing and excluded
steps](publication-visualization-v2_files/figure-html/viz2-paths-1.png)

Observed synthetic positions with lines only for QC-eligible steps.

### Only eligible speed measurements

![Observed speed from only valid source
steps](publication-visualization-v2_files/figure-html/viz2-speed-1.png)

Synthetic movement speeds calculated exclusively from QC-eligible steps.

### Source-row coverage

![Exact eligible, excluded and nonestimable source-row
coverage](publication-visualization-v2_files/figure-html/viz2-coverage-1.png)

Original source-row eligibility and missingness by synthetic track.

### Complete QC reason classification

![QC decision reason frequency for original
rows](publication-visualization-v2_files/figure-html/viz2-reasons-1.png)

Exclusion and non-estimability reasons retained from the QC ledger.

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
