# Audit observational versus independent experimental units

Audit observational versus independent experimental units

## Usage

``` r
aqt_inference_readiness(
  data,
  recording_col = "recording",
  animal_col = NULL,
  tank_col = NULL,
  treatment_col = NULL,
  animal_ids_verified = FALSE,
  tanks_independent_verified = FALSE,
  randomization_verified = FALSE,
  min_tanks_per_arm = 2L
)
```

## Arguments

- data:

  Observation data with recording and optional independent unit IDs.

- recording_col:

  Source recording identifier column.

- animal_col:

  Optional verified-animal identifier column.

- tank_col:

  Optional experimental tank identifier column.

- treatment_col:

  Optional treatment allocation column.

- animal_ids_verified, tanks_independent_verified,
  randomization_verified:

  Explicit scientific evidence declarations, never inferred from ID
  counts.

- min_tanks_per_arm:

  Minimum independently verified tanks per arm.

## Value

Conservative inference-readiness status without causal certification.
