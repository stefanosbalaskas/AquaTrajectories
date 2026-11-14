# Summarize mean average precision across fish classes and IoU thresholds

Average precision is first calculated per class. Classes absent from
manually verified ground truth are excluded from the macro mean;
detections in those classes remain reportable as false positives through
aqt_detection_metrics(). Uses the 101-point AP convention in
aqt_detection_ap(), not the full COCO benchmark protocol.

## Usage

``` r
aqt_detection_map(
  truth,
  pred,
  iou_thresholds = seq(0.5, 0.95, by = 0.05),
  evaluated_frames = NULL
)
```

## Arguments

- truth:

  Independent reference fish boxes.

- pred:

  Predicted boxes with confidence scores.

- iou_thresholds:

  IoU thresholds, typically 0.50:0.95 by 0.05.

- evaluated_frames:

  Optional explicitly reviewed frame manifest.

## Value

List containing by_class, by_threshold and mean_AP.
