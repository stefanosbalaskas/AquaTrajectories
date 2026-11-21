# Export QC 2.0 inclusion, exclusion and lineage evidence

Original source rows, canonical trajectories and the complete decision
ledger are exported separately, without overwriting existing files.
Manifests hash every output and reference the source input hash. This is
a reproducibility audit, not empirical ground-truth validation.

## Usage

``` r
aqt_qc2_export(report, directory)
```

## Arguments

- report:

  Output from aqt_qc2_report().

- directory:

  New output directory under an existing parent.

## Value

Output directory invisibly.
