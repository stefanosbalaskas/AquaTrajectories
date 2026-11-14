# Summarize empirical localization residuals by camera and session

This is descriptive measurement-error QC. Sample SDs from matched boxes
are not automatically unbiased estimates of detector noise, because the
matching threshold, annotator uncertainty, correlated errors and missed
detections can change the residual distribution.

## Usage

``` r
aqt_tracking_position_error_summary(errors)
```

## Arguments

- errors:

  Output of aqt_tracking_position_errors().

## Value

Per-session/camera residual bias, RMSE, SD and number of matches.
