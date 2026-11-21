# Declare source-axis semantics without silently inferring physical coordinates

Declare source-axis semantics without silently inferring physical
coordinates

## Usage

``` r
aqt_measurement_contract(
  axes,
  common_frame_verified = FALSE,
  calibration_reference = ""
)
```

## Arguments

- axes:

  Three-row data frame: axis (x/y/z), variable, unit, calibrated.

- common_frame_verified:

  Explicit verified common physical frame.

- calibration_reference:

  Independent calibration evidence identifier.

## Value

Contract whose physical_3d_eligible field is FALSE unless all three axes
are calibrated, physical and share a verified frame.
