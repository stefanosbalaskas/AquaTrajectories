# Plot swimming-speed changes around a known experimental intervention

Panel A plots mean speed across independent tank units after averaging
within each tank and time bin. Panel B plots paired before/after tank
averages; bars show descriptive across-tank SD, not a significance test.
The input speed must already be measured in the declared units.

## Usage

``` r
aqt_plot_speed_response(
  data,
  event_time_s,
  baseline_s = c(-30, 0),
  response_s = c(0, 30),
  speed_unit = NULL,
  tank_col = "tank_id",
  time_bin_s = 1,
  max_gap_s = 0.2
)
```

## Arguments

- data:

  Kinematic data.frame with tank_id,time_s,speed, or an aqt_tracks
  object with a known tank identifier column.

- event_time_s:

  Known intervention onset in time_s units.

- baseline_s, response_s:

  Two intervals relative to event_time_s, e.g. c(-30,0) and c(0,30).
  Intervals must not overlap.

- speed_unit:

  Explicit speed units (e.g. cm/s); for an aqt_tracks object can be
  inferred from its declared spatial units.

- tank_col:

  Name of independent experimental-unit identifier.

- time_bin_s:

  Time bin width in seconds.

- max_gap_s:

  Maximum allowed observed step when deriving speed from aqt_tracks. No
  interpolation across a lost observation.

## Value

Invisibly a list of time_bin, per_tank_epoch and summary tables.
