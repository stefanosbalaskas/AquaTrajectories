# Select stable provisional fish identities across camera views

Automatically choose geometrically supported, temporally stable,
one-to-one camera-local track-pair hypotheses; abstain on unresolved
ties.

## Usage

``` r
aqt_crossview_auto_associate(candidates, min_support = 3L,
  max_error = 0.5, ambiguity_margin = 0.05)
```

## Arguments

- candidates:

  Original refractive ray separation or pinhole reprojection candidates.

- min_support:

  Minimum distinct one-to-one observation pairs per stable match.

- max_error:

  Maximum eligible physical ray residual or pinhole pixel residual.

- ambiguity_margin:

  Required margin against geometrically tied competing links.

## Value

Object `aqt_crossview_association` with `correspondences`, `links`,
original candidate counts and provisional identity caveats.

## Details

Automatic camera-local track association is not independently reviewed
biological animal re-identification.
