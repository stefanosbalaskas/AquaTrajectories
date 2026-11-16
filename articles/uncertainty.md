# Uncertainty propagation and sensitivity analysis

## Uncertainty-aware aquatic trajectories

Uncertainty may originate in detector localization, tracking gaps,
camera clocks, optics, fish identity assignments, and experimental
sampling. The package makes several of these sources **explicitly
perturbable**, but their distributions require independent evidence.

![A conceptual outcome curve with a widening conditional sensitivity
band.](../uncertainty.svg)

Illustrative assumed scenarios; the band is not an empirically certified
confidence interval.

### Sources that should not be collapsed indiscriminately

| Source | Available utilities | Caution |
|----|----|----|
| Image pixel locations | [`aqt_stereo_pixel_mc()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_stereo_pixel_mc.md), [`aqt_reconstruction_pixel_uncertainty()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_reconstruction_pixel_uncertainty.md) | Requires assumed pixel error law |
| Coherent trajectory errors | [`aqt_trajectory_ensemble()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_trajectory_ensemble.md), [`aqt_ensemble_path_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_ensemble_path_summary.md) | Scenario SD is not automatically a confidence interval |
| Fish track ID switches | [`aqt_identity_switch_scenarios()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_identity_switch_scenarios.md), [`aqt_identity_tank_sensitivity()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_identity_tank_sensitivity.md) | Specified switch probabilities are not empirically calibrated |
| Optical parameters and correspondence | [`aqt_joint_refractive_scenarios()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_joint_refractive_scenarios.md), [`aqt_joint_event_sensitivity()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_joint_event_sensitivity.md) | Depends on supplied camera and identity perturbations |
| Experimental tank sampling | [`aqt_tank_event_contrast()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tank_event_contrast.md), [`aqt_joint_tank_sensitivity()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_joint_tank_sensitivity.md) | Keep external measurement error distinct from tank resampling |
| Detector dropout | [`aqt_detection_dropout_scenarios()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_dropout_scenarios.md), [`aqt_detection_event_sensitivity()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_event_sensitivity.md) | Performance depends on dropout model validity |

### A defensible reporting sequence

1.  Declare *which errors are measured* and which are only hypothetical.
2.  Preserve original source pixels and camera timestamps.
3.  Sample coherent scenarios rather than independently jittering every
    point when errors are correlated.
4.  Recalculate movement, state and event outcomes under each scenario.
5.  Report scenario ranges and assumptions separately from experimental
    sampling uncertainty.
6.  With independently measured holdout truth, assess bias and coverage
    before claiming calibrated intervals.

### Visual audit

Use
[`aqt_plot_ensemble2d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_ensemble2d.md),
[`aqt_plot_ensemble3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_ensemble3d.md),
[`aqt_plot_joint_scene_cloud()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_joint_scene_cloud.md)
and
[`aqt_plot_joint_scene_cloud3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_joint_scene_cloud3d.md)
for uncertainty overlays, always labeling them as **conditional
sensitivity** absent external calibration.

The package intentionally does not treat these hypothetical clouds as
verified biological identity probabilities or physically calibrated XYZ
confidence regions.

**Source protocols:** [source
protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/docs/TRAJECTORY_UNCERTAINTY.md),
[source
protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/docs/IDENTITY_SCENARIOS.md),
[source
protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/docs/JOINT_REFRACTIVE_SENSITIVITY.md)
and [source
protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/docs/EMPIRICAL_JOINT_UNCERTAINTY.md).
