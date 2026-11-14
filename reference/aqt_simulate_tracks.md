# Simulate deterministic mathematical fish paths

The random walks are testing fixtures and are NOT biologically
calibrated.

## Usage

``` r
aqt_simulate_tracks(
  n_fish = 5L,
  n_frames = 200L,
  fps = 30,
  dimension = 2L,
  seed = 7L
)
```

## Arguments

- n_fish:

  Positive integer number of animals.

- n_frames:

  Number of frames.

- fps:

  Positive sampling rate.

- dimension:

  Either 2 or 3.

- seed:

  Random seed.

## Value

Synthetic aqt_tracks in tank/cm units.
