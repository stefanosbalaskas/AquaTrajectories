# Plot an orthographic XY/XZ/YZ projection of a measured 3D fish scene

All three 2D projections use REAL XYZ coordinates rather than inventing
a missing depth. Draws only contiguous observed tail segments.

## Usage

``` r
aqt_plot_tank_projection(scene, plane = c("xy", "xz", "yz"))
```

## Arguments

- scene:

  Output of aqt_tank_scene_snapshot().

- plane:

  One of xy, xz, yz.

## Value

Scene invisibly and generates a base R plot.
