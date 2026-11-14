# Fit an independently maintained sparse FPCA backend to fish coordinates

Uses fdapace::FPCA when fdapace is installed. The backend is not
EyeTrajectories and this adapter does not claim native R parity for
unverified EyeTrajectories methods. Report the fdapace version and
verify temporal design coverage before interpreting eigenfunctions.

## Usage

``` r
aqt_sparse_fpca_fit(input, optns = list())
```

## Arguments

- input:

  aqt_sparse_fpca_input.

- optns:

  Additional fdapace options; dataType="Sparse" and plot=FALSE are
  enforced.

## Value

aqt_sparse_fpca_fit containing original backend result and metadata.
