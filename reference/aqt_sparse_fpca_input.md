# Convert incomplete aquatic trajectories to sparse functional observations

Prepares one coordinate at a time as ragged Ly/Lt lists for a separately
qualified functional-data backend. Only manually marked OBSERVED, finite
positions are retained. No linear interpolation or false 3D assumption.
Every camera/session/track scope forms one curve; researchers must
decide if these scopes are biologically independent and representative.

## Usage

``` r
aqt_sparse_fpca_input(
  tracks,
  coordinate = "x",
  time_axis = c("relative", "absolute"),
  min_points = 3L
)
```

## Arguments

- tracks:

  Canonical 2D/3D aqt_tracks with possible missing samples.

- coordinate:

  x, y, or z (z requires 3D).

- time_axis:

  "relative" rescales each complete recording time range to 0..1;
  "absolute" keeps the original session-clock seconds.

- min_points:

  At least 3 observed points per scoped fish.

## Value

aqt_sparse_fpca_input with Ly, Lt, scope, missingness audit, coordinate
units and time axis metadata.
