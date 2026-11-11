# Wave 7B — joint conditional optical, localization and fish-identity sensitivity

## Scientific objective

To examine whether 3D fish trajectory, event response and independently
tank-replicated treatment contrasts remain stable when several distinct
assumptions about video measurement vary *together*.

The full model is **conditional scenario sensitivity**, NOT a posterior,
confidence region or empirically coverage-calibrated estimator. Passing
synthetic tests does not demonstrate known real underwater accuracy.

## Native methods

- \`aqt_joint_refractive_scenarios()\`: starts from separately reviewed,
  clock-matched 2D views and two measured-parameter flat-port cameras.
  Each draw perturbs camera world centres once per camera (the same
  perturbation across all fish and frames); each glass thickness once per
  camera; each glass and water refractive index with a common offset
  across views; and each source image position using independent
  per-camera pixel localization jitter. It then retraces all air/glass/
  water rays and reconstructs physical XYZ. Optionally it applies
  explicitly proposed future-segment fish-ID swaps to coherent tracks.
  All source RNG state is restored. Nonphysical calibration scenarios
  are errors, not silently omitted samples.
- \`aqt_joint_event_sensitivity()\`: recalculates swimming observations
  and event-window summary values separately in every scenario. A draw
  missing its entire event result raises an error.
- \`aqt_joint_tank_sensitivity()\`: computes equal-weight, replicated-tank
  before/after treatment contrasts for EACH measurement scenario,
  including optional gap constraints. Tank resampling intervals remain
  visible *within* scenarios, distinct from the distribution of
  scenario-specific point estimates.

## Minimal idealized example

~~~r
library(aquaTrajectories)

# view_a/view_b: 2D aqt_tracks in pixel/image coordinates;
# reviewed: table with session_id,id_a,id_b,time_a_s,time_b_s,fish_id
# and optional tank_id/treatment for experimental inference.
# left/right: previously constructed aqt_flatport_camera objects.
sensitivity <- aqt_joint_refractive_scenarios(
  view_a,view_b,reviewed,left,right,
  pixel_sd=c(.5,.5),center_sd=c(.05,.05),
  glass_thickness_sd=.005,
  n_glass_sd=.002,n_water_sd=.001,
  draws=100,seed=41,
  max_skew_s=.02,max_ray_separation=.5
)

print(sensitivity$calibration_draws)
print(sensitivity$quality)

epochs <- aqt_joint_event_sensitivity(
  sensitivity,events,windows=list(
    baseline=c(-5,0),response=c(0,5)
  ),max_gap_s=.25
)

# With >=2 independent tanks in each treatment:
tank_effects <- aqt_joint_tank_sensitivity(
  sensitivity,events,
  windows=list(baseline=c(-5,0),response=c(0,5)),
  tank_bootstrap_draws=1000,max_gap_s=.25
)
print(tank_effects$per_draw)
print(tank_effects$conditional_95pct_range)
~~~

This is an API illustration; no external video or physical camera
parameter estimates are bundled with the package.

## Limitations that matter for scientific interpretation

1. Pixel, centre, glass thickness, and optical-index SDs are user-specified
   hypotheses. Their distributions have not been independently calibrated
   against physical tank records or annotation errors.
2. The camera-centre offset is global within one camera draw and the
   index offsets are common across cameras, but lens parameters,
   camera rotations, glass-plane orientation, glass nonplanarity, and
   clock timing are currently held fixed.
3. Identity swaps only represent user-proposed whole-future-track label
   hypotheses after independently reviewed cross-view fish matches.
   Cross-view correspondence itself is fixed, and no tracking posterior
   is estimated.
4. The system does NOT estimate a joint confidence interval combining
   measurement assumptions, biological variation and independent tank
   sampling. The tank-bootstrap intervals are kept separate by design.
5. Synthetic known-XYZ tests demonstrate code consistency on idealized
   geometry, NOT actual aquaculture measurements, coverage, biological
   welfare or causal treatment effects.
6. Identical errors shared across many frames can bias entire
   trajectories. Researchers should not resample video frames as if
   they were independent subjects or tanks.
7. Camera data, tracked fish, calibration records and experimental
   event logs must be independently audited before use.

## Research gap and future requirements

- Validate landmark geometry across the whole tank, all cameras,
  camera angles and fish depths.
- Estimate correlated measurement-error distributions from multiple
  independent reference annotations and known optical targets.
- Add coherent rotation, interface normal, focal length and clock
  drift uncertainty, with physically constrained covariance matrices.
- Cross validated multiple-hypothesis fish identity assignment.
- Study nominal interval coverage, bias, inferential stability and
  sensitivity to nonrandom occlusion on realistic annotated videos.
- Compare with existing movement and functional-statistics packages
  rather than claiming methodological novelty without benchmarks.

The scientific output is a *robustness experiment*, not a substitute
for calibration, independent tank replication or appropriate inference.
