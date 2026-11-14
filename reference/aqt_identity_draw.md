# Materialize one internally coherent identity-assignment scenario

Retains original_track_id and assignment_changed flags. Scenario swaps
are permutations of camera/session-local labels, not cross-camera
re-identification. An accepted swap affects all subsequent observations
for the affected identities.

## Usage

``` r
aqt_identity_draw(scenarios, draw = 1L)
```

## Arguments

- scenarios:

  Output from aqt_identity_switch_scenarios().

- draw:

  Scenario index, 1..draws.

## Value

Validated aqt_tracks with reassigned tracking labels.
