# Calculate audited movement only from reviewed, eligible observations

Rejected rows remain traceable; accepted movement steps require
adjacent, observed points and the recorded maximum time gap. The output
is descriptive and cannot certify true fish identity or physical speed
without calibration.

## Usage

``` r
aqt_qc_derive(review, max_gap_s = NULL)
```

## Arguments

- review:

  An aqt_qc_review from explicit aqt_qc_review().

- max_gap_s:

  Maximum interval used for valid movement steps.

## Value

aqt_qc_derived with kinematics, per-track path summary and counts.
