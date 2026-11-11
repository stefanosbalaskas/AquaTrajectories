# Wave 7A: canonical fish trajectories reconstructed through refractive optics

## Purpose

The earlier refractive optics modules reconstructed individual pixel
pairs through a one-interface or parallel air-glass-water camera model.
This module turns externally reviewed, synchronized camera-local fish
observations into canonical time-stamped 3D aqt_tracks, which can feed
the package's movement, school, event, sparse-functional, hierarchical
and sensitivity-analysis functions.

## Functions

- aqt_refractive_reconstruct_tracks(): joins explicit per-observation
  correspondences from two synchronized cameras, projects each
  verified pair through its physical refractive camera, performs
  positive-ray closest-distance triangulation and records source
  IDs, source timestamps, time skew, physical ray separation, and
  observed/invalid status. Optional tank_id and treatment metadata
  are retained for later independent-tank analyses.
- aqt_refractive_track_quality(): summarizes valid reconstruction
  counts, missingness, median and maximum underwater-ray separation,
  and maximum between-view timestamp skew within each session.

## Illustrative source geometry

~~~r
library(aquaTrajectories)

left <- aqt_flatport_camera(diag(3),diag(3),
  center=c(-1,0,-1),glass_front_point=c(0,0,0),
  glass_normal=c(0,0,1),glass_thickness=.1,
  n_first=1,n_glass=1,n_water=1,units="cm"
)
right <- aqt_flatport_camera(diag(3),diag(3),
  center=c(1,0,-1),glass_front_point=c(0,0,0),
  glass_normal=c(0,0,1),glass_thickness=.1,
  n_first=1,n_glass=1,n_water=1,units="cm"
)
view_a <- aqt_tracks(data.frame(
  session_id="S",camera_id="TOP",track_id="A",
  time_s=0:3,x=c(.5,.6,.7,.8),y=0
))
view_b <- aqt_tracks(data.frame(
  session_id="S",camera_id="SIDE",track_id="B",
  time_s=0:3,x=c(-.5,-.4,-.3,-.2),y=0
))
reviewed <- data.frame(
  session_id="S",id_a="A",id_b="B",
  time_a_s=0:3,time_b_s=0:3,fish_id="fish1",
  reviewer="independent annotator",reason="known geometry"
)
xyz <- aqt_refractive_reconstruct_tracks(
  view_a,view_b,reviewed,left,right,max_skew_s=.01
)
print(aqt_refractive_track_quality(xyz))
print(aqt_kinematics(xyz,max_gap_s=1))
~~~

These camera parameters are a non-refractive limiting test case and
NOT an independently calibrated tank or fish-video measurement.

## Scientific limitations

1. A valid ray intersection does NOT prove biological identity.
   The matching fish_id is supplied from a separately reviewed
   correspondence table; users must not infer it from camera IDs.
2. Camera intrinsics and extrinsics, both glass interface surfaces,
   timestamps and tank metric scale must be measured independently.
3. Physical ray separation is a QC diagnostic, not absolute XYZ
   accuracy. Incorrect calibration can produce small internal residuals.
4. One or both source observations may be missing. The reconstructed
   fish point is then marked NOT observed, never interpolated.
5. The module does not automatically propagate optical calibration
   or fish-identity uncertainty into XYZ or inferential intervals.
6. A single-camera video cannot reconstruct 3D depth with this method.
7. Group/fish measures computed at high video sampling rates do not
   represent independent experimental tanks or causal observations.

## Next research priority

Build coherent camera-parameter uncertainty draws, model alternative
cross-view identity assignments and propagate both into path/event
statistics with independent-tank experimental sampling handled
separately. Independently measured 3D fish tracks and known-landmark
benchmarks are essential for scientific accuracy certification.
