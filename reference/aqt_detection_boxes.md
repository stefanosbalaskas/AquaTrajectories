# Validate labelled detector bounding boxes

Reference and prediction boxes use the same format. Every box is a
nondegenerate axis-aligned rectangle in the same pixel coordinate
system. Frame identifiers must be scoped by session and camera. A
prediction must have confidence in \[0,1\]; reference boxes need no
confidence.

## Usage

``` r
aqt_detection_boxes(data, role = c("truth", "prediction"))
```

## Arguments

- data:

  Data frame: session_id, camera_id, frame_id, class_id, xmin, ymin,
  xmax, ymax; for predictions also confidence.

- role:

  Whether these are independent reference boxes or predictions.

## Value

A validated data frame of boxes.
