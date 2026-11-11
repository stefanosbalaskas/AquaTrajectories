# Wave 5A: native multivariate trajectory statistics

This module deliberately implements transparent, independently testable R
mathematics rather than importing incomplete EyeTrajectories R contracts.
EyeTrajectories remains a separate eye-movement analysis package.

## Algorithms

### Multivariate dynamic time warping

- aqt_trajectory_dtw(): minimizes the sum of pairwise Euclidean point
  distances subject to a monotone warping path and an optional
  Sakoe-Chiba band. Both 2D and true calibrated 3D positions are supported.
- aqt_trajectory_dtw_matrix(): compares 2-40 scoped animal trajectories.

The input must have complete, observed coordinates and consistent units and
dimension. Missing positions, duplicate timestamps and time gaps above
max_gap_s are errors. The total DTW cost changes with the number of
observations; mean_step_distance is additionally reported, but differing
sampling rates, trajectory duration, and spatial origins can still produce
unfair comparisons. The warping path is an analytical alignment, not
evidence that two physical fish are the same animal.

### Recurrence quantification

- aqt_trajectory_recurrence(): Euclidean observed-position recurrence with
  explicit radius, Theiler exclusion, minimum diagonal and vertical run
  lengths. Reports recurrence rate, diagonal-line determinism and
  vertical-line laminarity. Optionally stores the recurrence matrix.
- aqt_plot_recurrence(): base-R recurrence image from the returned matrix.

Recurrence statistics depend on the sampling rate, position uncertainty,
radius, trajectory section, tank spatial geometry and excluded near-time
pairs. In particular, determinism is a mathematical run-density measure,
not direct proof of deterministic animal behaviour.

### Dense-grid trajectory PCA

- aqt_trajectory_grid_pca(): individually registers each complete observed
  2D/3D fish path to relative duration [0,1], linearly interpolates onto a
  common evenly spaced grid, then applies ordinary PCA to the concatenated
  X/Y(/Z) coordinate vectors. Starting-position centering is optional
  and enabled by default.
- aqt_plot_grid_pca(): displays mean component curves and +/- 1 empirical
  component standard deviation, coordinate-by-coordinate.

This is explicitly **finite-grid multivariate PCA**. It is *not* continuous
FPCA with a functional measurement-error model, not sparse FPCA for occluded
fish and not a hierarchical model for multiple fish sharing a tank.
Relative-time alignment collapses absolute trajectory-duration information.
Researchers should analyze duration separately when it is meaningful.
The signs of components are arbitrary; eigenvectors/score magnitudes
depend on scale, grid resolution and origin convention.

## Minimal reproducible example

~~~r
library(aquaTrajectories)

tracks <- aqt_simulate_tracks(
  n_fish=5,n_frames=150,fps=15,dimension=3,seed=13
)

fish1 <- aqt_tracks(subset(as.data.frame(tracks),track_id=="fish1"),
  units="cm",coordinate_system="tank")
fish2 <- aqt_tracks(subset(as.data.frame(tracks),track_id=="fish2"),
  units="cm",coordinate_system="tank")

comparison <- aqt_trajectory_dtw(fish1,fish2,window=30)
print(comparison$distance)
print(head(comparison$path))

rqa <- aqt_trajectory_recurrence(
  fish1,radius=1.5,theiler=3,min_diagonal=2,
  store_matrix=TRUE
)
print(c(rqa$recurrence_rate,rqa$determinism,rqa$laminarity))
aqt_plot_recurrence(rqa)

pca <- aqt_trajectory_grid_pca(
  tracks,n_grid=60,n_components=2,origin="start",
  max_gap_s=.2
)
print(pca$scores)
print(pca$explained_variance)
aqt_plot_grid_pca(pca,component=1)
~~~

These simulator paths are mathematical test fixtures, not biologically
calibrated fish swimming patterns.

## Validation and limitations

1. Exact known-truth tests cover identical, offset and 3D DTW paths;
   recurrence counts are validated against manually enumerated patterns;
   grid PCA is validated on deterministic linear trajectories.
2. No attempt is made to automatically impute missing fish or bridge
   unobserved segments. This avoids converting occlusions into invented
   evidence.
3. The 2D versus 3D interpretation is explicit. A 2D recording is not
   silently converted to zero-depth 3D data.
4. Functional PCA under irregular sparse observation and qualified
   mixed-effects inference remain future scientific work.
5. Methods are descriptive. Neither DTW, recurrence nor trajectory PCA
   independently establishes stress, welfare, leadership, preference or
   causal effects.
6. Independent comparisons with qualified fish/animal trajectory packages,
   real annotated videos and known-truth camera calibration are required
   before a scientific methods manuscript can claim applied accuracy.
