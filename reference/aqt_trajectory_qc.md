# Audit video-derived aquatic trajectories without editing source observations

The original research bundle or caller-provided data are retained as
raw. Duplicate fish IDs, malformed positions, unmatched frames, invalid
source times, low confidence and excessive coordinate steps are flagged
on BOTH the row-level ledger and aggregate coverage tables. A gap flag
refers to a discontinuous step, not an automatically invalid point.

## Usage

``` r
aqt_trajectory_qc(
  input,
  frames = NULL,
  max_gap_s = 0.2,
  max_speed = NULL,
  max_jump_px = NULL,
  min_detection_confidence = NULL,
  expected_tracks = NULL,
  truth = NULL,
  evaluated_frames = NULL,
  max_reference_distance = NULL
)
```

## Arguments

- input:

  An imported aqt_research_bundle or raw observation data frame.

- frames:

  Complete frame manifest; omit for aqt_research_bundle input.

- max_gap_s:

  Maximum continuous observed movement interval, seconds.

- max_speed:

  Optional position-unit/second threshold; requires times.

- max_jump_px:

  Optional maximum image-space adjacent step in pixels.

- min_detection_confidence:

  Optional score threshold in \[0,1\].

- expected_tracks:

  Optional externally declared session_id,camera_id,track_id roster;
  used only for explicitly roster-based expected coverage.

- truth:

  Optional independent manually annotated point tracks.

- evaluated_frames:

  Explicit annotated frames, including empty frames.

- max_reference_distance:

  Distance tolerance for manual point tracking check.

## Value

An aqt_trajectory_qc object with raw, row_audit, coverage, optional
manual_accuracy, provenance, and an immutable source-of-truth audit
ledger.

## Details

Missing individual frames cannot be interpreted as detection false
negatives without an independently declared expected identity roster.
Inferred ID switches and biological stress/welfare are not measured by
this function.
