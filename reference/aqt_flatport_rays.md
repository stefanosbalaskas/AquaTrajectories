# Trace source pixels through both surfaces of a flat aquarium glass wall

The first surface is described by glass_front_point and glass_normal,
the second lies glass_thickness farther along the normal. The output is
a ray in the target (nominal water) medium. Invalid intersections or
total internal reflection remain explicit missing rays.

## Usage

``` r
aqt_flatport_rays(camera, pixels)
```

## Arguments

- camera:

  An aqt_flatport_camera.

- pixels:

  Undistorted source-image n-by-2 pixel coordinates.

## Value

World-space water ray origins/directions and valid flags.
