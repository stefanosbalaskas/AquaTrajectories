# Detection average precision using confidence-ranked 101-point interpolation

These are explicit IoU-based, per-class AP calculations, NOT identical
to full COCO evaluation (no crowd/ignore, area ranges or maxDets
conventions). Rankings are computed across all frames per species. AP is
0 if references exist but there are no predictions, NA when no reference
exists.

## Usage

``` r
aqt_detection_ap(
  truth,
  pred,
  iou_thresholds = seq(0.5, 0.95, by = 0.05),
  evaluated_frames = NULL
)
```

## Arguments

- truth:

  Independent labelled fish bounding boxes.

- pred:

  Predicted boxes with confidence scores.

- iou_thresholds:

  Overlap thresholds in (0,1\].

- evaluated_frames:

  Optional fully annotated frame manifest.

## Value

Per class and IoU threshold AP, n_truth and n_predictions.
