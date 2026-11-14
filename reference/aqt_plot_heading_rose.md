# Plot swimming-heading rose diagrams with explicit angle conventions

Uses supplied heading_rad values from aqt_kinematics() or another
documented 2D projected-heading source. Circular bins compare direction
distributions without claiming true 3D orientation. Optional preloaded
raster images can be shown beside each condition's polar rose.

## Usage

``` r
aqt_plot_heading_rose(
  data,
  bins = 16L,
  scale = c("fraction", "count"),
  clockwise = FALSE,
  zero_offset_rad = 0,
  weight_col = NULL,
  frame_rasters = NULL,
  fill = "#B0C36B"
)
```

## Arguments

- data:

  A data.frame with condition and heading_rad columns.

- bins:

  Number of angular bins (integer between 4 and 72).

- scale:

  One of fraction (bin proportion) or count (weighted count).

- clockwise:

  Whether angles increase clockwise rather than CCW.

- zero_offset_rad:

  Rotation of the supplied angle-zero direction.

- weight_col:

  Optional nonnegative observation-weight column.

- frame_rasters:

  Optional named list of preloaded raster images, with names matching
  conditions. Supplied images are not generated or altered.

- fill:

  Fill colour for rose diagram sectors.

## Value

Invisibly a table of bin centers, counts, proportions and descriptive
circular statistics.
