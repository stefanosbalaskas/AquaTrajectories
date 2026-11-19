# Export actual scientific figures and a provenance-linked publication report

Uses the exact precomputed aqt_scientific_analysis, emits only evidence-
supported figures, and records withheld figures and errors. Existing
native plotting helpers are reused for school dispersion and
independent-tank changes; other plots draw directly from already
gap-audited numerical data. PNG plus vector PDF and a self-contained
report/evidence archive are produced without introducing new numerical
estimates.

## Usage

``` r
aqt_research_publish(
  study,
  directory,
  formats = c("png", "pdf"),
  width = 7.8,
  height = 5.8,
  dpi = 220L,
  max_scopes = 3L,
  data_origin = c("unspecified", "synthetic", "real")
)
```

## Arguments

- study:

  Source-verified aqt_scientific_analysis.

- directory:

  New output folder; parent directory must already exist.

- formats:

  Unique nonempty selection of png or pdf.

- width, height:

  Physical figure dimensions in inches (3..15).

- dpi:

  PNG resolution in dots/inch, 100..600.

- max_scopes:

  Maximum distinct camera/session figure groups, 1..8.

- data_origin:

  Declared origin: unspecified, synthetic or real.

## Value

Output directory invisibly.
