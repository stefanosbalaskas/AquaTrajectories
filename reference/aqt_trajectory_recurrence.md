# Recurrence quantification for a complete 2D or 3D fish path

Euclidean position recurrence within a declared physical/pixel radius.
Excludes diagonal and short-temporal separations by a Theiler window.
Reports recurrence rate, diagonal-line determinism and vertical-line
laminarity. These are descriptive measures whose interpretation depends
on radius, sampling rate, tracking quality and tank geometry.

## Usage

``` r
aqt_trajectory_recurrence(
  track,
  radius,
  theiler = 1L,
  min_diagonal = 2L,
  min_vertical = 2L,
  max_gap_s = Inf,
  store_matrix = FALSE
)
```

## Arguments

- track:

  One validated scoped fish trajectory, with no missing samples.

- radius:

  Nonnegative recurrence distance in coordinate units.

- theiler:

  Exclude pair indices at \|i-j\| \<= this integer (default 1).

- min_diagonal:

  Minimum diagonal recurrence run length \>= 2.

- min_vertical:

  Minimum vertical recurrence run length \>= 2.

- max_gap_s:

  Largest permitted inter-observation gap.

- store_matrix:

  Return logical recurrence matrix for visualization.

## Value

Descriptive RQA diagnostics, optionally the recurrence matrix.
