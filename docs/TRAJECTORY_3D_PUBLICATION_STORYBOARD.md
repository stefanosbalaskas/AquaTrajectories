# Four-panel 3D fish trajectory storyboard

This is a **static publication-figure renderer**. It uses supplied
real 3D physical tank coordinates; it never estimates depth from 2D
camera tracks. It is separate from the interactive rgl tank scenes and
multiview video explorer.

## Example

```r
library(aquaTrajectories)

# Supply a verified or synthetic physical-XYZ 3D aqt_tracks object.
# It must contain one session/camera/fish (or specify all three IDs).
png("fish_trajectory_four_panels.png",width=2200,height=1500,res=220)

summary <- aqt_plot_trajectory_storyboard3d(
  tracks,
  times_s=c(0,20,40,60),
  session_id="S01",camera_id="FUSED3D",track_id="F01",
  recent_s=2,
  max_gap_s=.10,
  max_age_s=.10,
  tank_limits=list(x=c(0,22),y=c(0,8),z=c(0,11))
)

dev.off()
print(summary)
```

Set `times_s` to timestamps actually covered by the fish track.
For short synthetic datasets, omit `times_s` to choose four equally
spaced snapshots automatically. The explicit tank coordinates above
are examples, **not measurements of your real aquarium**.

A strict observation gap blocks the drawing and distance integration
of that transition. Grey depicts older observed segments, light blue
the previous recency window, and dark blue the most recent window.
Speed is the most recent valid measured segment speed, not a claim
about instantaneous speed. The annotation is **observed distance**,
not total travel when detections are missing.

The output is a standard base-R figure suitable for export to PNG,
PDF, SVG or TIFF without needing rgl. It does not certify underwater
camera calibration, fish identity accuracy, or biological validity.

## rgl regression fixes

The release branch corrects `rgl::plot3d()` calls for
`aqt_plot_school3d()`, `aqt_plot_voxel3d()` and
`aqt_plot_ensemble3d()`: use `col=`, not `color=`, in
the initial `plot3d` call. Regression tests exercise all three
with an optional headless rgl device. Existing multi-fish rgl
scenes remain available through `aqt_plot_tank_scene3d()`.
