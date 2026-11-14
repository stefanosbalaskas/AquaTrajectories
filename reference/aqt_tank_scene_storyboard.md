# Assemble bounded time-ordered 3D tank storyboard frames

Assemble bounded time-ordered 3D tank storyboard frames

## Usage

``` r
aqt_tank_scene_storyboard(
  tracks,
  times_s,
  tail_s = 3,
  max_age_s = 0.2,
  max_gap_s = 0.2,
  events = NULL
)
```

## Arguments

- tracks:

  A validated single-session 3D tank trajectory.

- times_s:

  Increasing finite requested clock timestamps, 1..200 frames.

- tail_s, max_age_s, max_gap_s:

  As in aqt_tank_scene_snapshot.

- events:

  Optional event log.

## Value

List of aqt_tank_scene objects keyed by frame clock time.
