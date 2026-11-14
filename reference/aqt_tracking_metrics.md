# Tracking identity F1 and within-camera association diagnostics

IDF1 is computed from globally optimal one-to-one identity assignment
over framewise position matches (per session/camera). Adjacent ID
switches count only directly consecutive annotated frames with
successful matches; they are NOT a substitute for official CLEAR MOT or
HOTA. For HOTA and published benchmark parity use an external,
independently validated TrackEval run with compatible annotations.

## Usage

``` r
aqt_tracking_metrics(
  truth,
  pred,
  max_distance,
  class_aware = TRUE,
  evaluated_frames = NULL
)
```

## Arguments

- truth, pred:

  Independent per-frame point-track tables.

- max_distance:

  Maximum spatial association error in coordinate units.

- class_aware:

  Match within class/species.

- evaluated_frames:

  Optional manifest of all manually annotated frames.

## Value

One row per session/camera with precision, recall, IDF1, positional
RMSE, adjacent identity switches, and transparent counts.
