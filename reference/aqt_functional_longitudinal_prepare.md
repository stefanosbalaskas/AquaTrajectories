# Validate fully supported event-relative fish curves for mixed models

Requires exactly one logged event and one session per independent tank,
one fixed between-tank treatment, \>=3 independent tanks per arm, \>=2
fish per tank, \>=6 equally spaced event-relative grid times, and
complete (supported, finite) fish curves at ALL times. Nonrandom
occlusion and incomplete curves are deliberately NOT imputed. This
strict contract supports a common AR(1) within-fish correlation model:
the time index is formed from a common equally spaced grid, never from a
row number of an incomplete trajectory.

## Usage

``` r
aqt_functional_longitudinal_prepare(
  grid,
  treatment_levels = c("control", "treatment")
)
```

## Arguments

- grid:

  aqt_functional_event_grid with tank_id and treatment.

- treatment_levels:

  Two ordered treatment labels.

## Value

aqt_functional_longitudinal_frame with nested fish scope, equally spaced
AR(1) time index and independent-tank design audit.
