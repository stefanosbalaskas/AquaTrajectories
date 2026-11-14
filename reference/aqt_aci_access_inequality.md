# Quantify observed inequality in use of offered device choices

Computes Gini inequality across per-fish multi-option exercise rates
within each session/tank. Each fish MUST have at least one opportunity
offering \>=2 alternatives; otherwise compare opportunity exposure
separately rather than treating unoffered fish as non-users. If no fish
selects, inequality is undefined, not falsely zero. Inequality is not
evidence of dominance or animal welfare.

## Usage

``` r
aqt_aci_access_inequality(choices)
```

## Arguments

- choices:

  aqt_aci_choice_log.

## Value

Per-tank observed exercise-rate Gini and exposure balance.
