# Define explicit candidate identity switches and draw coherent assignments

Each candidate event swaps two CURRENT assigned tracker labels in ONE
session/camera, from an explicitly recorded time onward. There is no
automatic biological identity recognition and no probability estimation:
probabilities must be justified by independent annotations or
sensitivity assumptions. Swaps are sampled once per crossing event and
applied to entire subsequent track segments, not independently to each
video frame.

## Usage

``` r
aqt_identity_switch_scenarios(
  tracks,
  candidate_events,
  draws = 200L,
  seed = 7L
)
```

## Arguments

- tracks:

  Canonical aqt_tracks with unique scoped track IDs per time.

- candidate_events:

  Table with session_id, camera_id, track_a, track_b, at_s and
  probability_swap. All required.

- draws:

  Number of assignment scenarios (\>= 1).

- seed:

  Integer RNG seed; preserves the global RNG state.

## Value

aqt_identity_scenarios containing original trajectories, candidate
switch events, and a draw-by-event logical decision matrix.
