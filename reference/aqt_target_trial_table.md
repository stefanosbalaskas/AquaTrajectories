# Validate an independently measured underwater stereo target experiment

Every trial contains externally measured physical XYZ and matching
undistorted 2D pixel observations in two cameras. Fit/holdout boards
must be disjoint in each trial to reduce same-board leakage. The caller
remains responsible for camera lens/refraction calibration, actual
physical landmark surveying and independent target collection.

## Usage

``` r
aqt_target_trial_table(data, units = c("cm", "m"))
```

## Arguments

- data:

  One row per target with trial_id,tank_id,session_id,
  camera_a_id,camera_b_id,target_id,target_group,partition,
  truth_x,truth_y,truth_z,a_u_px,a_v_px,b_u_px,b_v_px. partition is fit
  or holdout. All pixels must already be correctly undistorted for the
  corresponding camera model.

- units:

  Physical world XYZ units cm or m.

## Value

aqt_target_trials with explicit physical and external-truth
qualification flags.
