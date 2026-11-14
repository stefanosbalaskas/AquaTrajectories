# Import MOTChallenge/ByteTrack 2D detections using measured video PTS

Interoperability adapter for standard MOTChallenge comma-separated
tracker output: frame, id, left, top, width, height, confidence, ... The
first seven fields are required; extras are ignored. A ByteTrack result
exported in this convention can be read directly, but this function does
not execute a detector/tracker or infer fish identities. Frame numbers
are converted using frame_origin, typically 1, then mapped to a
\*complete\* video frame manifest (including empty frames). It never
uses a nominal FPS to create pseudo-accurate timestamps.

## Usage

``` r
aqt_import_mot(
  detections,
  frames,
  session_id,
  camera_id,
  frame_origin = 1L,
  class_ids = NULL
)
```

## Arguments

- detections:

  Data frame with \>=7 columns in MOTChallenge order, or a path to
  headerless comma-separated MOT text.

- frames:

  aqt_frame_manifest with the selected recording.

- session_id, camera_id:

  Nonempty camera-local recording identifiers.

- frame_origin:

  Raw MOT frame number representing frame_id zero; normally 1. Exact
  choice must reflect the exporter configuration.

- class_ids:

  Optional per-row species/label vector; otherwise fish. A track's class
  must not change without an externally reviewed split.

## Value

aqt_tracks in image pixels with source frame, bounding box, confidence,
class, PTS timing and explicit unqualified provenance.
