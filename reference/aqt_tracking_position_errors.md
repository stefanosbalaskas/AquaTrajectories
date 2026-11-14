# Extract matched position errors from independent annotated fish tracks

Reference and predicted 2D point tracks must use the same physical/image
coordinate units and frame IDs. All matches come from the existing
scoped, class-aware matching code. Maximum-distance association removes
large residuals, potentially truncating estimated error variability.

## Usage

``` r
aqt_tracking_position_errors(
  truth,
  pred,
  max_distance,
  class_aware = TRUE,
  evaluated_frames = NULL
)
```

## Arguments

- truth:

  Independent manually verified point tracks.

- pred:

  Automatic point tracks.

- max_distance:

  Threshold for pairing reference and estimate.

- class_aware:

  Require equal class_id within a match.

- evaluated_frames:

  Explicit manifest of annotated frames (recommended).

## Value

Matched signed x/y residuals and Euclidean errors.
