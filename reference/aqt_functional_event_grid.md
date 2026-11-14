# Align observed fish behaviour to event-relative functional time

Interpolates only between adjacent \*observed\* source samples separated
by at most max_gap_s. Missing source frames, insufficient coverage and
large gaps are never silently bridged. The time grid is in REAL seconds
relative to externally logged event onset, not warped to 0..1. Grouped
fish remain distinct; tank_id/treatment can be retained as observational
metadata, not treated as independent fish replicates.

## Usage

``` r
aqt_functional_event_grid(
  data,
  events,
  outcome = "speed",
  grid_s = seq(-5, 5, length.out = 21L),
  max_gap_s = 0.5
)
```

## Arguments

- data:

  Long frame with session_id, camera_id, track_id, time_s, numeric
  outcome and optional logical observed, tank_id, treatment.

- events:

  Canonical events, at most one per session.

- outcome:

  Numeric observed variable such as speed, x, y or z.

- grid_s:

  Strictly increasing finite event-relative seconds.

- max_gap_s:

  Largest permissible adjacent observation gap.

## Value

aqt_functional_event_grid with supported and missing grid points.
