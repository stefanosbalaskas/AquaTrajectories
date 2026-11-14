# Apply per-session validated clock fits without discarding raw timestamps

Rejects failed heldout clock checks by default, all absent
camera/session transforms and source times outside the pulse span beyond
an explicitly allowed extrapolation margin.

## Usage

``` r
aqt_sync_holdout_apply(
  tracks,
  fitted,
  require_tolerance = TRUE,
  max_extrapolation_s = 0
)
```

## Arguments

- tracks:

  Validated 2D/3D aqt_tracks.

- fitted:

  aqt_clock_holdout object.

- require_tolerance:

  Reject any failed camera/session holdout.

- max_extrapolation_s:

  Allowed outside-pulse clock seconds; zero requires all sample times
  within measured pulse span.

## Value

aqt_tracks with time_raw_s, synchronized time_s and heldout timing
diagnostics attached per observation.
