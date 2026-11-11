# Wave 4B — coherent trajectory measurement uncertainty

## Purpose

AquaTrajectories now evaluates the *sensitivity of fish movement summaries*
to explicit, hypothetical measurement-error models. This is an intermediate
building block between raw tracking QC, multiview geometry and eventual
scientifically calibrated statistical inference.

Wave 3B estimated conditional XYZ uncertainty from assumed camera image
localization noise under fixed pinhole triangulation. Wave 4B generalizes to
**coherent entire 2D/3D paths** and propagates the resulting position
scenarios through path and event-aligned movement analysis.

## Implemented functions

- aqt_tracking_position_errors() and aqt_tracking_position_error_summary():
  extract signed position residuals using independently annotated frames,
  preserving per-camera scope and admitting annotation/selection bias.
- aqt_trajectory_ensemble(): generate synthetic alternative 2D/3D paths
  under explicit axis-specific marginal error SD, adjacent-observation AR(1)
  correlation and per-track systematic offsets; preserve input R RNG state.
- aqt_ensemble_tracks(): materialize one complete simulated track table,
  retaining original identity, timestamps, units and observation flags.
- aqt_ensemble_path_summary(): calculate distances, speed and valid
  observation duration for each scenario and scoped fish.
- aqt_ensemble_event_summary(): recompute kinematics from each scenario
  and summarize responses inside predefined event-relative windows.
- aqt_ensemble_summarize(): descriptive SDs and empirical quantiles across
  measurement-only scenarios. These are NOT treatment confidence intervals.
- aqt_plot_ensemble2d() and aqt_plot_ensemble3d(): visualize alternative
  paths alongside the original with base graphics and optional rgl.

## Example

~~~r
library(aquaTrajectories)

tracks <- aqt_simulate_tracks(n_fish=5,n_frames=100,
                              fps=10,dimension=3,seed=1)
# Error in cm, not pixels: requires physically calibrated observations.
ensemble <- aqt_trajectory_ensemble(
  tracks,sigma=c(.2,.2,.4),rho=.7,
  systematic_sd=c(.1,.1,.15),draws=100,seed=42,
  max_gap_s=.25
)

changes <- aqt_ensemble_path_summary(ensemble,max_gap_s=.25)
effects <- aqt_ensemble_summarize(changes,value_col="mean_speed")
print(effects)

aqt_plot_ensemble3d(ensemble,
  session_id="S01",camera_id="SIM",track_id="fish1",n_draws=12)
~~~

A 2D example can replace dimension=3 with dimension=2 and use
aqt_plot_ensemble2d() instead.

## Scientific limitations and validation standards

1. All uncertainty summaries are **conditional sensitivity** results
   under a researcher-selected noise scenario, not statistically validated
   confidence/credible intervals for actual fish locations or treatment.
2. AR(1) correlation is defined across consecutive observed samples and
   resets on missing positions and max_gap_s breaks. It is not a
   continuous-time stochastic motion model or biologically validated noise.
3. Per-track systematic shifts are added coherently within a track.
   This does not represent camera rig calibration covariance across fish,
   coherent cross-camera geometry or fish identity switches.
4. Fish IDs are fixed. Multiple plausible cross-camera assignments,
   tracking occlusion, fish identification errors, detector bias and
   informative missingness require distinct discrete uncertainty models.
5. Source-localization SDs estimated after distance-threshold matching
   are potentially selected/truncated; manual reference annotation
   errors and field conditions are not yet calibrated.
6. Units must be explicit. Pixel-based tracks produce pixel-unit noise,
   whereas calibrated XYZ tracks produce cm/m-unit noise. Both are
   sensitive to calibration and observer geometry.
7. Smoothing, temporal interpolation, frame decimation and noisy
   numerical differentiation are still independent error sources.
8. Tank-level experimental sampling uncertainty is NOT represented by
   within-fish position perturbations. Treatment inference still needs
   independent tanks and design-appropriate models.
9. Real-data qualification must compare empirical error distributions,
   time autocorrelation and parameter calibration across species,
   cameras, shadows, occlusions and environments.
10. CRAN/CI success tests implementation consistency, not measurement
    error calibration or scientific novelty.

## Next research tasks

- Estimate hierarchical multi-camera errors from independent references,
  with non-Gaussian outliers, missingness and ID-switch scenarios.
- Respect stereo covariance matrices and joint perturbations of camera
  calibration parameters and clock offsets.
- Quantify coverage on independent known-3D trajectories and under
  simulated/realistic spatial error models.
- Reuse selected qualified EyeTrajectories functional and recurrence
  methods on 2D/3D paths with explicit dimensional semantics.
- Integrate camera, trajectory and experimental uncertainty without
  confusing the levels of variance.
