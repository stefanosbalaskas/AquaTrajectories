# Static three-axis observation plot, including explicitly mixed-unit axes

This visualises three recorded variables; it does not calculate 3D
speed.

## Usage

``` r
aqt_source_3axis_preview(data, contract, max_points = 4000L)
```

## Arguments

- data:

  Source observations.

- contract:

  Output of aqt_measurement_contract().

- max_points:

  Maximum evenly indexed observations to display.

## Value

Selected row indices, invisibly.
