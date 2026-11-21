# Inventory the entire public native and optional 3D plot gallery

Reads the package's live public namespace, so new aqt_plot\_\* exports
cannot silently disappear from the inventory. Execute all renderers with
scripts/viz2_gallery_matrix.R to check real output and 3D scene
geometry.

## Usage

``` r
aqt_viz2_gallery()
```

## Value

Exactly one row per public aqt_plot\_\* renderer, or an error.
