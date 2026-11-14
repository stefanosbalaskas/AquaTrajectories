# Declare the video frames covered by manual ground-truth annotation

A reference dataset may annotate only sampled video frames. Evaluation
must never interpret predictions on unannotated frames as false
positives. Include frames with zero fish to score false positives on
empty frames.

## Usage

``` r
aqt_evaluation_frames(data)
```

## Arguments

- data:

  Data frame with session_id, camera_id, frame_id.

## Value

Unique ordered frame manifest.
