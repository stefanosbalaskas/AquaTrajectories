# Dense-grid approximation to multivariate functional trajectory PCA

Each scoped fish path is independently registered to 0..1 relative time,
linearly resampled to a common grid and decomposed by ordinary PCA on
concatenated X/Y(/Z) grid coordinates. This is an explicitly finite-grid
PCA approximation, NOT sparse FPCA, continuous functional mixed models,
temporal causality inference, or a qualified EyeTrajectories backend.
Starting-position centering optionally removes constant translation.
Irregular source sampling is accepted only when no gap exceeds
max_gap_s.

## Usage

``` r
aqt_trajectory_grid_pca(
  tracks,
  n_grid = 60L,
  n_components = 2L,
  origin = c("start", "absolute"),
  max_gap_s = Inf
)
```

## Arguments

- tracks:

  Validated aqt_tracks with \>=3 complete scoped fish paths.

- n_grid:

  Integer common relative-time grid size, 5..1000.

- n_components:

  Number of principal components, 1..min(n_fish-1,p).

- origin:

  start (subtract initial XYZ) or absolute coordinates.

- max_gap_s:

  Largest source interval allowed for interpolation.

## Value

aqt_grid_pca containing scores, mode curves, mean path, relative-time
grid, and variance explained.
