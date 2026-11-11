# Wave 5B: fish-school geometry and 3D spatial visualization

This module builds descriptive spatial statistics from synchronized,
validated fish trajectories with explicit camera, session and timestamp
scope. A fish ID produced by a tracker is NOT assumed to be a permanent
biological identity across camera views or recording sessions.

## Functions

- aqt_group_pairwise_distances(): one Euclidean separation per unordered
  simultaneously observed pair, respecting 2D/3D and the units of the
  source trajectories.
- aqt_group_spatial_summary(): school centroid XYZ, radius of gyration,
  mean pair distance, maximum pairwise extent and number of visible fish.
- aqt_group_spatial_edges(): undirected thresholded proximity network.
  A proximity edge does not imply leadership, preference or interaction
  strength.
- aqt_voxel_entropy(): Shannon bits and normalized occupancy entropy
  over a predeclared 3D grid, explicitly counting samples outside the grid.
- aqt_plot_school3d(): optional interactive rgl 3D fish positions for one
  camera/session/time snapshot, with scoped fish-ID labels.
- aqt_plot_voxel3d(): optional interactive rgl plot of occupied 3D voxel
  centres; marker sizes indicate observed sample fraction.
- aqt_plot_school_dynamics(): publication-style time series of group
  radius, extent or mean pairwise distance, using base R graphics.

## Exact geometry example

~~~r
library(aquaTrajectories)

fish <- aqt_tracks(data.frame(
  session_id="S01",camera_id="FUSED3D",time_s=0,
  track_id=c("A","B"),
  x=c(0,3),y=c(0,4),z=c(0,12)
),units="cm",coordinate_system="tank")

pair <- aqt_group_pairwise_distances(fish)
stopifnot(pair$distance==13)

school <- aqt_group_spatial_summary(fish)
stopifnot(school$radius_gyration==6.5)

aqt_plot_school3d(fish,"S01","FUSED3D",0)

vox <- aqt_voxel_occupancy(
  fish,list(x=c(-1,2,5),y=c(-1,2,6),z=c(-1,6,13)),
  by="group"
)
entropy <- aqt_voxel_entropy(vox)
aqt_plot_voxel3d(vox)
~~~

The geometry uses idealized coordinates solely for mathematical validation.

## Limitations

- All metrics exclude non-observed fish and use exact co-timestamps.
  If cameras have clock differences, synchronize and validate timestamps
  *before* these functions; do not concatenate camera-local IDs.
- Numbers of fish visible at each time can vary. Apparent changes in
  cohesion or extent may reflect occlusions, fish detection errors, or
  incorrect identity assignments.
- Physical metric units cm/m require externally qualified calibration;
  3D graphics do not prove underwater camera metrology.
- Proximity networks are spatial graphs, not inferential social graphs.
  They do not prove leadership, aggression, social preference or agency.
- Voxel Shannon entropy is based on observed samples. Irregular frame
  intervals, missing detections, tank boundaries and grid resolution
  affect numerical values. This is not time-continuous residence entropy.
- Tank-level treatment inference still requires independently replicated
  tanks; a pair distance at 30 FPS is not an independent experimental unit.
- Comparisons with validated collective movement packages and real fish
  videos are required before claims of generalizable scientific novelty.
