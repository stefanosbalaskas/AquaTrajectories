# All simultaneous observed inter-fish distances within a camera/session

Each unordered pair is reported once for each exact shared timestamp.
Original camera-local fish IDs are used; identities are never merged
across cameras or interpreted as permanent biological identifiers.
Missing or non-observed fish are excluded explicitly. Units are
inherited from the tracks and are physical only after valid spatial
calibration.

## Usage

``` r
aqt_group_pairwise_distances(tracks, max_pairs = 1000000L)
```

## Arguments

- tracks:

  Validated 2D/3D aqt_tracks.

- max_pairs:

  Maximum output pairs, to avoid accidental data explosion.

## Value

Long table of camera-local fish pairs and Euclidean distances.
