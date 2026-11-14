# Prepare fish-within-tank event measurements for hierarchical analysis

Requires at least two independent experimental tanks per treatment arm
and exactly two observed epochs for every scoped fish. A tank must not
change assigned treatment. An event is included once per fish: studies
with many events, crossovers, autoregressive designs or interference
need a different statistical model.

## Usage

``` r
aqt_hierarchical_event_prepare(
  epochs,
  treatment_levels = c("control", "treatment"),
  epoch_levels = c("baseline", "response")
)
```

## Arguments

- epochs:

  Data frame with tank_id, treatment, camera_id, track_id, epoch, value;
  event_id is optionally allowed but must be unique.

- treatment_levels:

  Exactly c(control,treatment).

- epoch_levels:

  Exactly c(baseline,response).

## Value

Validated aqt_hierarchical_event_frame with factors for treatment,
epoch, tank_id and fish-within-tank.
