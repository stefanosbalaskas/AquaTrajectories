# Plot a projected uncertainty scenario cloud without Gaussian assumptions

Each 3D sample is plotted as a semi-transparent dot, with marginal
median position markers for each identity label. Such medians can lie
BETWEEN distinct identity modes; they are not reconstructed fish or
estimates of anatomical position in a real video frame.

## Usage

``` r
aqt_plot_joint_scene_cloud(cloud, plane = c("xy", "xz", "yz"))
```

## Arguments

- cloud:

  aqt_joint_scene_cloud.

- plane:

  XY, XZ or YZ projection of existing physical XYZ.

## Value

Cloud invisibly and creates a base R figure.
