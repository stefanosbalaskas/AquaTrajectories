# Reconstruct 3D from already-matched calibrated pinhole observations

Uses DLT. It does not identify corresponding fish across camera views,
estimate camera calibration, or correct air/water/glass refraction.

## Usage

``` r
aqt_triangulate_pairs(xy1, xy2, P1, P2)
```

## Arguments

- xy1, xy2:

  Matched numeric n-by-2 image coordinate matrices.

- P1, P2:

  Finite numeric 3-by-4 pinhole projection matrices.

## Value

Reconstructed x/y/z, reprojection RMSE and a valid flag.
