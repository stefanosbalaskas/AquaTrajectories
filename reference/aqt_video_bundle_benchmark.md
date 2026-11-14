# Score a verified single-camera bundle on independently annotated frames

Requires an explicit frame manifest of ALL fully annotated evaluation
frames, including zero-fish frames, plus separately annotated truth
detection boxes and point tracks. A sampled annotation schedule is
allowed but its coverage is reported and never extrapolated to
unannotated frames. No ground truth is generated from the prediction.

## Usage

``` r
aqt_video_bundle_benchmark(
  bundle,
  truth_boxes,
  truth_tracks,
  evaluated_frames,
  max_position_error_px = 15,
  iou_threshold = 0.5,
  confidence_threshold = 0.25
)
```

## Arguments

- bundle:

  aqt_video_bundle with verified file hashes.

- truth_boxes:

  Independent bounding boxes: session_id,camera_id,
  frame_id,class_id,xmin,ymin,xmax,ymax. May be zero rows.

- truth_tracks:

  Independent stable per-video fish identities:
  session_id,camera_id,frame_id,track_id,x,y,class_id.

- evaluated_frames:

  ALL fully annotated frame IDs, including those with no fish. Must be a
  subset of this video bundle.

- max_position_error_px:

  Positive pixel matching cutoff.

- iou_threshold:

  Detection matching overlap threshold.

- confidence_threshold:

  Detection confidence cutoff.

## Value

aqt_video_annotation_benchmark with per-class and pooled detection
metrics, camera-local identity metrics, independent annotation coverage,
no claims of real-fish validation unless supplied annotations actually
come from independent researchers.
