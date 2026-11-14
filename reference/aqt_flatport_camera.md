# Parameterize two parallel air-glass-water optical interfaces

Models an undistorted perspective camera in the first medium facing a
measured parallel planar glass slab. Light is traced through first
medium -\> glass -\> target medium, obeying Snell's law at BOTH
boundaries. The camera orientation, intrinsics, interface normal/point
and glass thickness are externally supplied calibration quantities. This
does not fit them, validate real glass planarity or correct lens/fisheye
distortion, dome ports or rolling shutter.

## Usage

``` r
aqt_flatport_camera(
  K,
  R_c2w,
  center,
  glass_front_point,
  glass_normal,
  glass_thickness,
  n_first = 1,
  n_glass = 1.5,
  n_water = 1.333,
  units = "cm"
)
```

## Arguments

- K:

  Finite intrinsic matrix for UNDISTORTED source pixels.

- R_c2w:

  Proper camera-to-world rotation.

- center:

  Source camera optical centre in common world coordinates.

- glass_front_point:

  World-space point on camera-side glass surface.

- glass_normal:

  Normal from camera-side medium into glass and water.

- glass_thickness:

  Positive physical slab thickness along the normal.

- n_first, n_glass, n_water:

  Positive refractive indices.

- units:

  World units in cm or m.

## Value

aqt_flatport_camera with explicit two-interface model.
