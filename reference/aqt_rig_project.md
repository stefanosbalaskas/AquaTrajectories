# Project known world XYZ positions into one camera's image plane

This performs projective pinhole geometry, not aquatic refraction.

## Usage

``` r
aqt_rig_project(rig, points, camera_id)
```

## Arguments

- rig:

  Camera rig.

- points:

  Numeric n-by-3 XYZ matrix in rig units.

- camera_id:

  Camera in rig.

## Value

Data frame of projected x, y and valid flags.
