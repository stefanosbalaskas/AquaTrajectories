# Assemble a claim-limited, machine-readable scientific evidence summary

Assemble a claim-limited, machine-readable scientific evidence summary

## Usage

``` r
aqt_evidence_report(
  specification,
  readiness,
  measurement = NULL,
  spatial = NULL,
  geometry = NULL,
  placebo = NULL
)
```

## Arguments

- specification:

  Output of aqt_compare_specifications().

- readiness:

  Output of aqt_inference_readiness().

- measurement:

  Optional measurement contract.

- spatial:

  Optional spatial-support audit.

- geometry:

  Optional camera-geometry audit.

- placebo:

  Optional within-file placebo audit.

## Value

Structured evidence report and dynamically derived statements.
