# Timestamp-aware 2D/3D swimming kinematics

No missing segment is bridged; derivatives are unsmoothed, so positional
noise can strongly affect acceleration and turning estimates.

## Usage

``` r
aqt_kinematics(tracks, max_gap_s = Inf)
```

## Arguments

- tracks:

  Validated aqt_tracks.

- max_gap_s:

  Largest time step eligible for movement calculation.

## Value

Data frame including dt_s, step_distance, vx/vy/vz, speed, heading_rad,
acceleration and turn_rate_rad_s.
