# Validate an independently exported video frame timing manifest

Video timestamps should be actual presentation timestamps (PTS) or a
separately verified equivalent, not an inferred frame/fps clock. Frame
IDs are always zero-based integers. Gaps are allowed and disclosed;
timestamps must increase strictly within each session/camera.

## Usage

``` r
aqt_frame_manifest(data)
```

## Arguments

- data:

  Data frame with session_id, camera_id, frame_id, time_s, width_px and
  height_px. Include frames with zero fish detections.

## Value

aqt_frame_manifest with exact observed frames and image sizes; frame
PTS, physical camera synchronization and provenance remain externally
verified responsibilities.
