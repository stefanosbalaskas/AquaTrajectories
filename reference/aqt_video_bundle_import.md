# Read a complete, SHA-256-checked Python video tracking export bundle

The optional PyAV/YOLO/ByteTrack runner emits a frame PTS table, an
MOTChallenge tracker table, an exact class-ID sidecar and JSON metadata.
All outputs must have the same prefix and match their recorded hashes,
row counts, source camera/session, frame origin and class-row keys. This
refuses partial, mixed-run and silently reordered sidecar files. The
source video/model hashes are recorded but are NOT checked unless the
user separately provides those files for independent verification.

## Usage

``` r
aqt_video_bundle_import(directory, prefix)
```

## Arguments

- directory:

  Directory containing the four completed runner files.

- prefix:

  Safe output prefix passed to the Python video runner.

## Value

aqt_video_bundle, with validated 2D tracks, all acquired video frames,
class sidecar, local source metadata and support audit. No biological
fish classification or camera calibration is certified.
