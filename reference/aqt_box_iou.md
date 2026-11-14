# Calculate pairwise intersection over union of axis-aligned rectangles

Calculate pairwise intersection over union of axis-aligned rectangles

## Usage

``` r
aqt_box_iou(truth, pred)
```

## Arguments

- truth, pred:

  Data frames with xmin/ymin/xmax/ymax.

## Value

Numeric n_truth-by-n_pred IoU matrix.
