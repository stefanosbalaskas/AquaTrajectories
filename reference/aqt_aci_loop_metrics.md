# Summarize animal-action to physical-device contingency by trial group

Reports P(observed actuation \| verified action), P(observed actuation
\| no annotated action), and their difference. This contingency is
DESCRIPTIVE, not proof of animal understanding, preference, agency, a
learned causal relationship or welfare. Counts use opportunities, not
fish-camera video frames.

## Usage

``` r
aqt_aci_loop_metrics(trials, group_cols = c("session_id", "fish_id"))
```

## Arguments

- trials:

  Output of aqt_aci_trials().

- group_cols:

  Grouping columns such as session_id, fish_id or condition. Session_id
  must always be included.

## Value

Per-group counts, detector and actuator reliability and descriptive
contingency differences.
