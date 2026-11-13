# Wave 15B — empirically calibrated *joint* fish detection, identity, timing and 3D uncertainty

The existing native R `aqt_joint_refractive_scenarios()` offers coherent
**conditional sensitivity** for camera-centre, optical index, pixel
localization and identity-swap assumptions, but cannot by itself estimate
real calibration-error distributions from external measurements.

This new Python component implements the **empirical calibration stage**:
`inst/python/aqt_joint_empirical_uncertainty.py`.

## Actual expected independent training data

Provide `--empirical-source-csv` containing **original paired**
external truth and AquaTrajectories prediction rows. Columns are
exactly:

`tank_id,session_id,fish_id,time_s,partition,truth_x,truth_y,truth_z,pred_x,pred_y,pred_z,detection_success,identity_correct,pixel_error_a_px,pixel_error_b_px,camera_clock_error_s,calibration_geometry_error_units`

Each external row represents **the same observed fish and camera
capture event**, so detector failure, fish-ID correctness, optical,
time, pixel and measured XYZ errors preserve the dependence that
would be destroyed by independently resampling different error
datasets. `pred_x/y/z` are **blank** for failed detections:
missing fish are *not imputed* as successful 3D positions.

`partition` is `train` or `holdout`, and **all records from a
real tank must belong to the same partition**. Train and holdout
fish frames from the same tank are rejected even if fish IDs and
timestamps differ. Original tank-level experimental independence,
fish identities, source camera clock and XYZ physical surveying
must be established by external observers; the script cannot
verify their physical authenticity from self-reported CSV alone.

## Two-stage joint estimator

1. **Empirical correlated residual population:** preserve all
   seven measured error components within each original row:
   XYZ residuals, pixel residuals from both views, camera clock
   residual and refractive optical calibration geometry residual.
   Sample entire training tank clusters before sampling
   observations within that tank. Estimate covariance from
   independent training-tank means rather than treating
   video frames as independent experimental units.
2. **Conservative finite-sample tank-block radial conformal error:**
   use the **maximum** correctly identified/detected fish radial XYZ
   error per training tank. Any source detection or identity failure
   makes that tank's unconditional all-fish radius score infinite.
   The order statistic `ceil((n_train_tanks+1)*(1-alpha))`
   yields an exploratory cluster-level all-observation containment
   radius when sufficient independent training tanks and zero
   precluding failures exist. The report refuses to return a
   finite unconditional interval when this order statistic is
   unavailable or infinite. Original unseen heldout tank
   containment, source-ID failure and detector failures are
   **reported separately, with complete denominators**.

A finite-sample coverage interpretation requires exchangeable tank
clusters, valid independent source truth, prespecified confidence
level and absence of distribution drift. The script's cluster
maximum conforms to the *original observed fish set within each
tank*, not arbitrarily to another species with new fish density.
For new video frames/animal behaviour no unqualified interval
promise is made.

### Command

```bash
python inst/python/aqt_joint_empirical_uncertainty.py \
  --empirical-source-csv /data/independent_fish_and_physical_targets.csv \
  --alpha 0.05 --draws 2000 --seed 713 \
  --out /data/evidence/joint_empirical_calibration.json
```

The report has original source SHA256, per-tank holdout diagnostics,
joint covariance over measured error components, real-scope
correlated draws, detection/ID missingness denominators and
**three explicit scientific-certification FALSE flags**.

## Scope of feature completion

The module implements the missing **empirical uncertainty calibration
algorithm and evidence format**. No real independent fish ID +
surveyed XYZ + camera pulse calibration table has been supplied.
Its regression tests use constructed synthetic known-truth tanks,
not a scientifically measured underwater fish experiment.

This therefore advances the software part of priority 5 but cannot
close the empirical validation criterion without original measurements
and third-party review. The native R conditional scenario estimator
and the new empirical component should eventually be tied to one
production scenario-draw API and linked to end-to-end pipeline outputs.
Issues: [#51](https://github.com/stefanosbalaskas/AquaTrajectories/issues/51).
