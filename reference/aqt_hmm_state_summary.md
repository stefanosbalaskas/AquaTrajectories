# Summarize decoded fish states without pseudoreplication

Reports per-scoped-fish observation counts, classified fractions and
Viterbi switching counts. Switches never cross tracking gaps, missing
rows or independently decoded segments. Fractions count VIDEO SAMPLES,
not physical durations or independent experimental replicates. Neither
this summary nor its state posterior is a tank-level treatment test,
calibrated confidence interval or fish welfare endpoint.

## Usage

``` r
aqt_hmm_state_summary(decoded)
```

## Arguments

- decoded:

  An aqt_hmm_states object from aqt_hmm_decode.

## Value

One row per fish and state, retaining optional tank/treatment IDs.
