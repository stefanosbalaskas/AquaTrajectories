# Snapshot verified XYZ fish positions and unbridged recent movement

Selects the LAST recorded fish observation at or before the requested
frame. A fish is visible only if that LAST observation is observed,
fully finite and at most max_age_s old; earlier positions are NEVER
silently reused after an explicitly missing observation. Recent tail
segments are split at missed frames and long timestamp intervals. Source
camera/identity metadata remains in the heads.

## Usage

``` r
aqt_tank_scene_snapshot(
  tracks,
  frame_s,
  tail_s = 3,
  max_age_s = 0.2,
  max_gap_s = 0.2,
  events = NULL
)
```

## Arguments

- tracks:

  Validated, measured XYZ 3D tank coordinates from one session and one
  fused camera. No 2D depth approximation permitted.

- frame_s:

  Snapshot time in session-clock seconds.

- tail_s:

  Past seconds to display as recent fish tracks.

- max_age_s:

  Largest permissible age of the most recent measured fish.

- max_gap_s:

  Largest contiguous observed tail interval.

- events:

  Optional canonical external event table.

## Value

aqt_tank_scene holding visible heads, segmented observed tails,
currently active and recently logged event IDs and units.
