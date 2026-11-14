# Extract time-locked physical fish positions under all joint scenarios

Uses the most recent observation in each coherent optical/identity
scenario, retaining only finite and explicitly observed XYZ no older
than max_age_s. Missing or occluded fish are NOT backfilled. Because
discrete fish-ID alternatives can be multimodal, returns every observed
XYZ draw rather than fitting an unwarranted Gaussian ellipsoid.
Summarizes per-label visibility and marginal coordinate quantiles only.

## Usage

``` r
aqt_joint_scene_cloud(
  scenarios,
  session_id,
  frame_s,
  max_age_s = 0.2,
  probs = c(0.05, 0.5, 0.95)
)
```

## Arguments

- scenarios:

  An aqt_joint_refractive_scenarios from the validated joint
  pixel/flat-glass/identity scenario generator.

- session_id:

  Exactly one preexisting session/tank recording ID.

- frame_s:

  Requested recording time in seconds.

- max_age_s:

  Maximum permitted age of the last observed fish.

- probs:

  Three increasing marginal descriptive quantiles, default 5th, 50th,
  95th percentiles. NOT confidence limits.

## Value

aqt_joint_scene_cloud with every 3D sample, visibility counts, optional
label assignment-change frequencies and units.
