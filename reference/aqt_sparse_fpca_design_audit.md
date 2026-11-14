# Audit sparse functional observation coverage in common time bins

Low coverage or many snippet-like curves can make the mean and
covariance surface poorly identified. This audit does not certify PACE
smoothing bandwidth, eigenfunctions or uncertainty coverage.

## Usage

``` r
aqt_sparse_fpca_design_audit(input, bins = 10L)
```

## Arguments

- input:

  Output of aqt_sparse_fpca_input().

- bins:

  Integer 5..100 equal-width support bins.

## Value

Per-bin counts of distinct fish curves with data.
