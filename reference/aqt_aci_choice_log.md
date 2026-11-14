# Validate externally recorded animal choice opportunities and selections

A long table contains one row per candidate option, fish and trial. An
option may be unavailable (offered=FALSE) but cannot be selected unless
offered. Each fish/trial chooses at most one option; a non-selection is
explicitly allowed. Option sets with \>=2 offered alternatives count as
"choice opportunities" for this descriptive module; a single offered
option is not evidence of free choice.

## Usage

``` r
aqt_aci_choice_log(data)
```

## Arguments

- data:

  Long table with session_id,tank_id,fish_id,trial_id,
  option_id,trial_s,trial_end_s,offered,selected,choice_s. choice_s is
  numeric NA for non-selected options.

## Value

aqt_aci_choice_log with offered option set and choice latency.
