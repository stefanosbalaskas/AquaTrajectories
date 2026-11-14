# Plot tank-level spatial occupancy trajectories and uncertainty bands

The supplied area_fraction is averaged within tank and time bins BEFORE
calculating across-tank variation. This prevents fish frames from being
treated as independent biological replicates. Bands are descriptive
between-tank SD or SE, not confidence intervals or significance tests.

## Usage

``` r
aqt_plot_occupancy_timeseries(
  data,
  time_bin_s = 60,
  band = c("sd", "se", "none"),
  periods = NULL
)
```

## Arguments

- data:

  Long table with scenario,tank_id,time_s,area_fraction.

- time_bin_s:

  Bin width in seconds; zero or negative not allowed.

- band:

  One of sd, se, or none; only shown where at least two distinct tank
  units contribute to a time bin.

- periods:

  Optional start_s/end_s/label table of known experimental periods,
  displayed as shaded regions; not inferred from behaviour.

## Value

Invisibly a tank-equal-weight summary by scenario and time bin, with
n_tanks and descriptive SD/SE.
