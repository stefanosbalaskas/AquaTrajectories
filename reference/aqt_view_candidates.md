# Generate geometric cross-view match candidates without assigning fish IDs

Candidate pairs require shared session, temporally compatible
observations and valid two-view pinhole triangulation. Each source
detection may appear in MANY hypotheses. Reprojection error ranks
geometrical consistency, not biological identity. Refraction or an
unknown optical path is rejected.

## Usage

``` r
aqt_view_candidates(
  view_a,
  view_b,
  rig,
  max_skew_s = 0.02,
  max_candidates = 100000L
)
```

## Arguments

- view_a, view_b:

  Two different camera-local 2D image aqt_tracks.

- rig:

  Explicitly non-refractive, calibrated aqt_rig.

- max_skew_s:

  Max allowed absolute difference between frame timestamps.

- max_candidates:

  Maximum possible pairs to materialize.

## Value

Candidate hypotheses including source scoped track/time IDs, XYZ,
reprojection error and time skew. No candidate is automatically
accepted.
