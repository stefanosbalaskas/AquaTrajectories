# Detection precision, recall, F1 and one-to-one match counts

Precision is undefined (NA) when no predictions exist, except that
unobserved classes are omitted. Recall is undefined without references.
F1 is 0 when one of the defined precision/recall values is zero;
otherwise undefined if either input is undefined.

## Usage

``` r
aqt_detection_metrics(
  truth,
  pred,
  iou_threshold = 0.5,
  confidence_threshold = 0.25,
  evaluated_frames = NULL
)
```

## Arguments

- truth, pred:

  Reference and predicted boxes.

- iou_threshold:

  Match threshold.

- confidence_threshold:

  Prediction confidence cutoff.

- evaluated_frames:

  Optional fully annotated frame manifest.

## Value

Per-class rows plus a micro-pooled ALL row.
