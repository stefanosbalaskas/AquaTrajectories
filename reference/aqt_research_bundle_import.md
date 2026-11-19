# Import a versioned Python-to-R aquatic tracking research bundle

Research Bundle v1 accepts externally produced YOLO/ByteTrack,
YOLO/BoT-SORT and idtracker.ai tracks in the same audit-checked schema.
Recorded timestamps are never inferred from nominal FPS. Where time
status is unknown, raw observations remain available but `tracks` is
NULL and time-based scientific analysis is intentionally blocked.

## Usage

``` r
aqt_research_bundle_import(directory)
```

## Arguments

- directory:

  Completed Research Bundle v1 directory.

## Value

An `aqt_research_bundle` list with `observations`, `frames`, `tracks`
(or NULL), `metadata` and provenance.
