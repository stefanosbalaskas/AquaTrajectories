# Export numerical source-linked fish measurement validation

This writes the already-computed source-preserving M08 measurement
audit. Reports are descriptive and explicitly withhold unmeasured
physical/biological conclusions; original frames and fish observations
are not modified.

## Usage

``` r
aqt_reference_measurement_publish(study, directory)
```

## Arguments

- study:

  Output of aqt_reference_measurement_validate.

- directory:

  New output directory; parent must exist.

## Value

New destination directory invisibly.
