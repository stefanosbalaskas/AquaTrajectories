# Publish a frame-indexed observation-quality and movement report

Exports audited descriptive tables, an RDS scientific object,
independent source-specific trajectory and group plots,
PNG/SVG/vector-PDF figures, embedded-SVG self-contained HTML and
Markdown reports, and an unkeyed SHA-256 output manifest. The figures do
not infer physical time or establish animal identity accuracy.

## Usage

``` r
aqt_frame_index_publish(study, directory)
```

## Arguments

- study:

  Output of
  [`aqt_frame_index_analyze()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_frame_index_analyze.md).

- directory:

  A new destination directory whose parent already exists. Previous
  results are not overwritten.

## Value

The new publication directory, invisibly.
