# Wave 9A — three-dimensional tank scenes and event-aware storyboard

## Scope

These functions visualize **already reconstructed, physically measured 3D
XYZ trajectories**. They deliberately do not infer Z from ordinary 2D
videos, perform fish detection/re-identification, or claim camera
calibration based on a visually plausible image.

A camera's source fish IDs remain scoped within the recorded session.
Plotting multiple tracks does NOT prove they are permanently
re-identified fish across cameras.

## Functions

- \`aqt_tank_scene_snapshot()\` selects only the last observation at or
  before a requested clock time for each fish. The last observation
  must be valid and no older than a declared maximum. A recently missing
  fish is never substituted with an earlier visible location. Historical
  tail points are broken into separate line segments at missing frames
  and excessive time gaps. External active/recent event IDs are included.
- \`aqt_tank_scene_storyboard()\` produces a finite, chronological list
  of verified snapshots for reproducible figures and frames.
- \`aqt_plot_tank_projection()\` makes XY, XZ and YZ orthographic
  projections of the SAME actual 3D positions, with the active
  event annotation. This enables headless PDF graphics.
- \`aqt_plot_tank_scene3d()\` uses optional \`rgl\` to show measured
  XYZ fish heads and gap-separated recent paths in physical space.

## Example

~~~r
library(aquaTrajectories)

# xyz is a single-session 3D aqt_tracks from independently qualified
# stereo/refraction calibration and reviewed cross-view fish matches.
# events is an explicit event log with session_id,event_id,start_s,end_s.
frame <- aqt_tank_scene_snapshot(
  xyz,frame_s=60,tail_s=5,max_age_s=.10,
  max_gap_s=.10,events=events
)
print(frame$heads[,c("track_id","x","y","z","age_s")])
print(frame$active_events)
aqt_plot_tank_projection(frame,plane="xz")

# Optional rgl installed:
# aqt_plot_tank_scene3d(frame)

frames <- aqt_tank_scene_storyboard(
  xyz,times_s=seq(60,65,by=.25),
  tail_s=3,max_age_s=.10,max_gap_s=.10,events=events)
~~~

## Scientific and visualization caveats

1. A 3D path is only as accurate as underwater optics, image
   annotations, camera clocks and fish correspondence.
2. Empty/occluded/expired observations do not become 3D dots.
   Tails are not drawn across observation gaps.
3. The visualization does not yet display full optical/identity
   uncertainty volumes. The scene field
   \`measurement_uncertainty_displayed\` is FALSE.
4. Fish positions are plotted as points; there is no inferred body
   orientation or biologically accurate fish shape.
5. This is **not** synchronized playback of actual recorded GoPro
   video frames. Linking video bitstreams, event telemetry and UI
   seeking requires an additional controlled data/video adapter.
6. Camera/source IDs are not automatically matched across views.
   One session plus one fused 3D camera scope is required per scene.
7. Coordinate units and an externally measured physical tank
   coordinate system are required.
8. Species-specific stress and welfare cannot be inferred solely
   from geometric trajectory visualization.

## Future interactive tank explorer

An eventual interactive research panel should provide linked
camera footage, XYZ trajectories, tank meshes, event timelines,
per-fish kinematics, school graphs and uncertainty-scenario
comparisons. A future browser/UI layer must reuse these verified
scene objects and offer a clearly labeled scientific status
for camera calibration and identity assignment.
