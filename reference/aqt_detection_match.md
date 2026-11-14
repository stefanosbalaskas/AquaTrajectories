# Match fish detections to independent ground-truth boxes

Matching maximizes valid pair cardinality independently for each
session, camera, frame, and class at an IoU threshold. Each reference
and predicted box can match at most once. The matching is deterministic.

## Usage

``` r
aqt_detection_match(
  truth,
  pred,
  iou_threshold = 0.5,
  confidence_threshold = 0,
  evaluated_frames = NULL
)
```

## Arguments

- truth:

  Reference boxes.

- pred:

  Predicted boxes with confidence.

- iou_threshold:

  Overlap threshold, inclusive.

- confidence_threshold:

  Predictions below this value are omitted.

- evaluated_frames:

  Optional manifest of fully annotated video frames.

## Value

Long table with TP, FP, FN statuses, source row indices and IoU.
