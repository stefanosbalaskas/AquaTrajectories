# Construct a validated aquatic-animal trajectory table

Construct a validated aquatic-animal trajectory table

## Usage

``` r
aqt_tracks(data, units = "px", coordinate_system = "image")
```

## Arguments

- data:

  Data frame with session_id, camera_id, track_id, time_s, x, y;
  optional z and observed.

- units:

  Coordinate units: px, cm, or m.

- coordinate_system:

  image or tank.

## Value

An aqt_tracks object. IDs only apply within session and camera.
