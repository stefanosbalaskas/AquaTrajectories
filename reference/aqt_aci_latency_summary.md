# Summarize measured fish-device loop latency without timing imputation

Means and medians are computed only for observed timestamp pairs; the
number with complete end-to-end records is always reported. Sessions
must be grouped explicitly; a null stage is NOT assigned latency zero.

## Usage

``` r
aqt_aci_latency_summary(trials, group_cols = c("session_id", "fish_id"))
```

## Arguments

- trials:

  aqt_aci_trials.

- group_cols:

  Grouping columns including session_id.

## Value

Per-group stage latency medians and complete-trial fractions.
