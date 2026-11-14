# Simulate coherent glass-camera and discrete fish-ID uncertainty scenarios

For each scenario: draw one physical calibration perturbation for EACH
camera (shared across all video frames), one shared glass/water-index
offset across the two views, camera-pixel localization errors, then
reconstruct 3D reviewed correspondences through both glass interfaces.
Optionally sample whole-suffix fish identity swaps, not independent
identity labels at each frame. All SD inputs are externally assumed
sensitivity parameters, NOT calibrated noise distributions.

## Usage

``` r
aqt_joint_refractive_scenarios(
  view_a,
  view_b,
  correspondences,
  camera_a,
  camera_b,
  identity_events = NULL,
  pixel_sd = 0,
  center_sd = 0,
  glass_thickness_sd = 0,
  n_glass_sd = 0,
  n_water_sd = 0,
  draws = 50L,
  seed = 123L,
  max_skew_s = 0.02,
  max_ray_separation = Inf
)
```

## Arguments

- view_a, view_b:

  2D image aqt_tracks for distinct cameras.

- correspondences:

  Externally reviewed cross-camera fish matches, optionally with tank_id
  and treatment fields.

- camera_a, camera_b:

  Two aqt_flatport_camera optical models.

- identity_events:

  Optional prospective swaps of reconstructed fish labels, using
  session_id,camera_id="REFRACTIVE3D", track_a,track_b,
  at_s,probability_swap. Only user-specified hypotheses are considered.

- pixel_sd:

  One/two standard deviations in image pixels.

- center_sd:

  One/two physical SDs of camera centre positions.

- glass_thickness_sd:

  One/two physical glass thickness SDs.

- n_glass_sd, n_water_sd:

  Shared dimensionless optical-index SDs.

- draws:

  Number of coherent uncertainty scenarios (\>= 10).

- seed:

  Reproducible integer seed; caller RNG remains unchanged.

- max_skew_s, max_ray_separation:

  Clock and physical ray QC limits.

## Value

aqt_joint_refractive_scenarios with per-draw 3D tracks, physical
calibration draws, diagnostics and assumptions.

## Details

An optical draw that creates invalid glass or ray geometry FAILS
explicitly; it is never silently omitted from ensemble summaries.
