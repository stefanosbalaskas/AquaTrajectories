# Export a source-linked publication figure without altering the source data

This device wrapper accepts a zero-argument drawing function, including
a closure that calls an existing aqt_plot\_\* function. It exports
identical R plot commands to PNG, vector PDF, SVG and TIFF, but the
physical raster appearance can differ by R graphics device and operating
system. Every file is hashed; a new destination is required and partial
outputs are removed on error. Does not alter the input or infer
scientific results.

## Usage

``` r
aqt_figure_export(
  draw,
  directory,
  formats = c("pdf", "png"),
  width = 7,
  height = 5,
  dpi = 300L,
  source_file = NULL,
  caption = ""
)
```

## Arguments

- draw:

  Zero-argument drawing function; should create one R base/grid plot.

- directory:

  New directory for exported figures.

- formats:

  One or more of pdf, png, svg, tiff.

- width, height:

  Physical figure dimensions in inches.

- dpi:

  Raster resolution, dots/inch.

- source_file:

  Optional existing input file to hash (never copied).

- caption:

  Optional researcher-supplied description.

## Value

New output directory invisibly.
