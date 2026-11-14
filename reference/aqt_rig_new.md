# Construct a calibrated pinhole camera rig

Projection matrices must use one common metric world-coordinate system.
Declaring an optical interface does not correct refraction: 3D pinhole
reconstruction explicitly refuses such rigs.

## Usage

``` r
aqt_rig_new(
  projections,
  units = "cm",
  optical_path = c("unknown", "air_only", "refractive_interface")
)
```

## Arguments

- projections:

  Named list of at least two finite 3-by-4 pinhole P matrices.

- units:

  World-position units, cm or m.

- optical_path:

  One of air_only or refractive_interface.

## Value

A validated aqt_rig object.
