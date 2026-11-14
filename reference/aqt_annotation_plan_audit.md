# Audit prespecified video-frame annotation sample support and coverage

This checks the recorded sampling design against an acquired-frame
manifest, not truth of fish labels or human reviewer independence.
\\n_frames_selected\\ must never be confused with fish-level or
independently treated tank-level replication.

## Usage

``` r
aqt_annotation_plan_audit(plan, frames)
```

## Arguments

- plan:

  aqt_annotation_plan from aqt_annotation_frame_plan().

- frames:

  Original aqt_frame_manifest from the same video recordings.

## Value

aqt_annotation_plan_audit list with per-video and per-temporal stratum
acquired/sample counts and inclusion probabilities.
