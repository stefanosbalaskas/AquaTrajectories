# Wave 9B — 3D uncertainty clouds for optical and fish-identity scenarios

## Research goal

Underwater video-derived XYZ trajectories are estimates conditional
on camera geometry, source point localization and fish identities.
A single nominal line can hide how much an inferential result
depends on those assumptions.

Earlier AquaTrajectories waves built coherent perturbations of
flat-port glass parameters, camera centres, camera pixels, and
whole-future-track identity exchanges. Here each such scenario
contributes its ACTUAL physical XYZ fish positions to an
event-time-indexed visualization. We do NOT fit an unwarranted
multivariate normal approximation to potentially MULTIMODAL
identity assignments.

## Functions

- \`aqt_joint_scene_cloud()\` accepts previously generated
  \`aqt_joint_refractive_scenarios\`, a session and a requested
  recording timestamp. For each scenario, it selects only the last
  real observed fish position at or before that time with a
  prespecified maximum age, exactly as in the existing
  observed-only tank scene. A missing fish is never replaced
  by an earlier recording. The function retains each
  (draw, fish identity label, XYZ) row and reports visibility
  fraction, identity-reassignment frequency, and marginal
  descriptive coordinate quantiles.
- \`aqt_plot_joint_scene_cloud()\` draws the full cloud in XY, XZ
  or YZ, colour-coded by fish assignment label. The cross marker
  is a marginal median, which can lie between competing physical
  identity modes and is NOT a physically measured fish.
- \`aqt_plot_joint_scene_cloud3d()\` offers optional rgl XYZ
  3D points. It displays the full sample cloud, not one
  Gaussian ellipsoid per fish.

## Usage

~~~r
library(aquaTrajectories)

# scenarios: output of the validated
# aqt_joint_refractive_scenarios() API
scene <- aqt_joint_scene_cloud(
  scenarios,session_id="TANK_01",
  frame_s=120,max_age_s=.05,
  probs=c(.05,.5,.95)
)
print(scene$summary)
print(scene$points)

aqt_plot_joint_scene_cloud(scene,plane="xz")
# Optional interactive rgl:
# aqt_plot_joint_scene_cloud3d(scene)
~~~

**Important:** this example presupposes a physically calibrated
camera setup and independently reviewed fish correspondences. The
software does not provide those external measurements automatically.

## Measurement safeguards

1. Every supplied measurement scenario must contain the
   requested session and one consistent fused 3D camera system.
   Units must match and be physical (cm or m); 2D image pixels
   cannot be silently promoted to 3D world coordinates.
2. Every visible fish contributes at most one XYZ observation
   to a given draw and selected clock time. Missing,
   nonobserved or stale fish have no plotted point.
3. All proposed fish labels remain in the visibility audit,
   including those absent in every scenario at a frame.
4. The between-scenario spread is conditional on the
   researcher-specified error distributions and identity
   alternatives. It is NOT a calibrated posterior or
   confidence distribution for biological fish position.
5. The plotted marginal x/y/z quantiles are separate
   coordinate summaries, NOT simultaneous 3D confidence
   regions. They may conceal multimodality; use the full
   scenario point table in analyses.
6. The outputs do not summarize animal welfare, preference,
   causality, statistical power or experimental tank
   replication. Those require distinct analyses.
7. A scenario can represent an incorrect fish identity
   without an actual tracking algorithm having detected
   or resolved that biological identity.
8. Correlated camera errors can move every fish in a draw
   together; the visualized points must not be treated as
   independent measured fish.

## Next validation

- Compare spread and nominal coordinate quantiles with
  independently measured 3D XYZ targets.
- Quantify true coverage under known optical and identity
  perturbations, across tank depths and glass-viewing angles.
- Link the time-indexed clouds to the Wave 9A tank storyboard
  and event telemetry in a dedicated interactive UI,
  preserving a red/neutral label for uncalibrated methods.
- Consider multimodal clustering and density estimators
  only when their biological/mathematical interpretation is
  justified and tested against known truth.
