# Match separately observed fish positions to reference tracks

Per-frame maximum-cardinality matching uses Euclidean distance in
coordinate units. It is class-aware by default and returns only actual
one-to-one matched pairs. This is not a cross-view matching method.

## Usage

``` r
aqt_tracking_match(
  truth,
  pred,
  max_distance,
  class_aware = TRUE,
  evaluated_frames = NULL
)
```

## Arguments

- truth, pred:

  Independent truth and predicted point-track tables.

- max_distance:

  Positive maximum positional error for association.

- class_aware:

  Restrict matches to identical species labels.

- evaluated_frames:

  Optional manifest of all manually annotated frames.

## Value

One row per matched pair, with original row IDs and distance.
