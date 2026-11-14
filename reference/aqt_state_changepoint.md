# Detect penalized mean changes in one complete fish behaviour series

Finds global optimal piecewise-constant means under a user-declared
nonnegative squared-unit penalty per additional segment and minimum
sample count per segment. No hidden interpolation, time warping,
statistical p-values or causal claims. This is a descriptive model.
Irregular timestamps are retained but the SSE objective weights samples
equally, not by duration; for irregular high-rate recordings use
externally justified pre-aggregation before comparing experiments.

## Usage

``` r
aqt_state_changepoint(
  data,
  outcome = "speed",
  penalty,
  min_segment = 5L,
  max_gap_s = Inf
)
```

## Arguments

- data:

  Data frame with a single session_id/camera_id/track_id, strictly
  ordered unique time_s and a finite numeric outcome.

- outcome:

  Name of observed numeric behaviour feature, e.g. speed.

- penalty:

  Nonnegative cost in squared outcome units per break.

- min_segment:

  Minimum observations in every segment (\>=3).

- max_gap_s:

  Largest allowed time interval; gaps raise errors.

## Value

aqt_changepoints with segment means, change-point time midpoints and a
fully audited objective.
