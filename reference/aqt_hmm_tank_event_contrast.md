# Compare two-arm fish HMM event changes with tank-level resampling

Reuses the existing aqt_tank_event_contrast() tank-bootstrap contract,
after the strict per-fish and per-tank posterior aggregation above.
Reports treated-minus-control differences in within-tank change of
sample-averaged HMM posterior probability. Independent tank bootstrap is
a sensitivity interval, not calibrated coverage or causal evidence.

## Usage

``` r
aqt_hmm_tank_event_contrast(
  epochs,
  treatment_levels = c("control", "treatment"),
  draws = 499L,
  level = 0.95,
  seed = 7L
)
```

## Arguments

- epochs:

  aqt_hmm_tank_epochs from aqt_hmm_event_tank_epochs.

- treatment_levels:

  Two ordered treatment labels.

- draws, level, seed:

  Tank-level bootstrap parameters.

## Value

aqt_hmm_tank_event_contrast, retaining fish QC and original tank-level
resampling estimates and explicit scientific limitations.
