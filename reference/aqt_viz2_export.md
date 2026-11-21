# Export audited publication figures and exact plotted-data evidence

Creates PDF/SVG vectors and PNG/TIFF raster files through the existing
figure exporter. Journal presets supply physical size and dpi. Uses a
transaction-staged, non-overwriting directory and SHA-256 manifest
linking both original scientific evidence and every exported output to
exact plotted points, eligible movements, and QC source-row decisions.
Device bytes, fonts and anti-aliasing can vary across operating systems;
byte-identical cross-OS PDF/SVG/TIFF files are NOT claimed.

## Usage

``` r
aqt_viz2_export(spec, directory, formats = c("pdf", "svg", "png", "tiff"))
```

## Arguments

- spec:

  Validated, unmodified aqt_viz2_spec.

- directory:

  New output directory under an existing parent.

- formats:

  Unique selected formats pdf,svg,png,tiff.

## Value

New output directory invisibly; no outputs on failure.
