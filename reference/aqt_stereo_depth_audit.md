# Summarize 3D reconstruction accuracy across prespecified tank depths

Uses true measured Z to classify depth ranges, not reconstructed Z;
reports coverage and RMSE separately in each range.

## Usage

``` r
aqt_stereo_depth_audit(benchmark, depth_breaks)
```

## Arguments

- benchmark:

  aqt_stereo_landmark_benchmark.

- depth_breaks:

  Increasing physical Z cutpoints including all reference landmarks; at
  least two intervals.

## Value

Depth-group calibration accuracy and invalidity.
