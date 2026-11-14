# Audit tracker support against actual video frame availability

Measures missing detections \*among acquired video frames\* between
successive observations of the same camera-local identity; dropped video
frames are excluded rather than mislabelled as occlusions. Missing
detections alone cannot distinguish occlusion, tracker failure, fish
leaving view, or identity swaps.

## Usage

``` r
aqt_mot_support_audit(tracks, frames)
```

## Arguments

- tracks:

  aqt_mot_tracks from aqt_import_mot.

- frames:

  The exact aqt_frame_manifest used for import.

## Value

Per-scoped-track acquired-frame support, missed acquired frames between
detections, frame gaps and video time spans.
