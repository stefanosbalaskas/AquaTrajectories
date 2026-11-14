# Plot the mean 2D/3D trajectory and one dense-grid PCA mode

Shows mean +/- one empirical component SD in each coordinate versus
registered relative time. This is a descriptive mode visualization, not
an interval for fish behaviour or a reconstructed 3D shape.

## Usage

``` r
aqt_plot_grid_pca(fit, component = 1L)
```

## Arguments

- fit:

  aqt_grid_pca.

- component:

  One component index.

## Value

PCA fit invisibly; creates a base R multi-panel figure.
