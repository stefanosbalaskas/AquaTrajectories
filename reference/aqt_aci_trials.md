# Validate externally annotated fish-device interaction trials

One row records one declared fish opportunity and its optional observed
action, detector trigger, control command, physical actuator observation
and verified fish response. All clocks must have been synchronized into
the same session time base before use.

## Usage

``` r
aqt_aci_trials(data)
```

## Arguments

- data:

  Frame with session_id, trial_id, fish_id, opportunity_s, end_s,
  action_s, detection_s, command_s, actuator_s, response_s. Absent
  timestamps are numeric NA. Optional tank_id and condition.

## Value

aqt_aci_trials with validated event sequences and latency fields.

## Details

Missing action with a detection means a PROPOSED false trigger,
conditional on the annotation's accuracy; it is not discarded.
Downstream device stages may not appear before their predecessor.
