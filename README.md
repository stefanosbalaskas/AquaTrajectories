# AquaTrajectories

Development-stage native R package for aquatic animal 2D/3D trajectories, movement metrics, event alignment, synchronization, and calibrated multiview geometry.

**Not an independently validated release.** Fish detector training, cross-camera identity matching, aquatic refraction correction, physiological stress detection, and coverage-calibrated statistical inference are not implemented.

## First-wave example

~~~r
library(aquaTrajectories)
x <- aqt_simulate_tracks(n_fish = 5, n_frames = 200)
kin <- aqt_kinematics(x, max_gap_s = 0.1)
school <- aqt_group_metrics(x, max_gap_s = 0.1)
aqt_plot_paths(x)
event <- aqt_event_table(data.frame(
  session_id = "S01", event_id = "routine_event", start_s = 3, end_s = 4
))
aligned <- aqt_align_events(kin, event)
~~~

The simulator produces purely synthetic random walks, not biologically calibrated fish behaviour.

## Core scientific guarantees

Camera- and session-scoped track IDs are not permanent animal identities. A 2D trajectory has unknown depth, not z = 0. Missing positions and long intervals are not silently interpolated. Pinhole stereo triangulation requires externally matched points and is inappropriate for uncorrected refraction. Camera-clock alignment is not physical exposure synchronization. Tank-level experimental replication and independent welfare validation remain necessary.

See docs/SCIENTIFIC_ROADMAP.md for planned advanced functionality and status.


## Wave 2: independently evaluated detectors and trackers

This development branch adds validation of independent fish detections
and individual identity assignments. The two accuracy problems are separate.

- Detection: aqt_detection_boxes(), aqt_box_iou(),
  aqt_detection_match(), aqt_detection_metrics(), aqt_detection_ap(),
  and aqt_detection_map(). Includes precision, recall, F1, IoU and
  confidence-ranked 101-point AP/mAP; NOT full COCO benchmark semantics.
- Identity tracking: aqt_tracking_observations(), aqt_tracking_match(),
  aqt_tracking_metrics(). Reports framewise matches, optimal global IDF1,
  adjacent ID switches and positional RMSE per session and camera.
  HOTA / official CLEAR MOT are NOT implemented.
- Ground-truth scope: aqt_evaluation_frames() makes sparse manual
  annotation explicit. Include manually reviewed empty frames.
- Provenance: aqt_provenance_new(), aqt_provenance_verify().
  File digests provide change detection, not authentication.
- Human corrections: aqt_apply_identity_corrections() maintains the
  original IDs and reviewer-provided correction log.

### Minimal validation demonstration

~~~r
truth <- data.frame(
  session_id="S1",camera_id="top",frame_id="0",class_id="fish",
  xmin=0,ymin=0,xmax=20,ymax=10
)
prediction <- transform(truth,confidence=.94)
aqt_detection_metrics(truth,prediction,confidence_threshold=.25)
aqt_detection_map(truth,prediction,iou_thresholds=c(.5,.75))

reference <- data.frame(session_id="S1",camera_id="top",
  frame_id=0:2,track_id="A",x=0:2,y=0)
estimate <- transform(reference,track_id=c("1","1","3"))
aqt_tracking_metrics(reference,estimate,max_distance=.1)
~~~

For assumptions, reference-label requirements, and scope limitations,
see docs/VALIDATION_CONTRACT.md.


## Wave 3A: calibrated known-correspondence stereo trajectories

Two (or more) named projection matrices define aqt_rig_new().
Use aqt_rig_project() and aqt_rig_baseline() for camera geometry.
aqt_reconstruct_3d() joins externally known cross-camera fish matches
at their actual, synchronized observation timestamps; 3D results carry
reprojection RMSE, camera timestamp differences and source fish IDs.
aqt_reconstruction_quality() summarizes those diagnostics.
aqt_voxel_occupancy() provides observed XYZ sample counts in predefined
physical-volume cells, and aqt_plot_reconstruction_qc() plots geometry/
clock diagnostics.

This stage is **strict known-correspondence pinhole stereo**, not automatic
cross-view matching, through-glass calibration, fisheye correction or
refraction-aware underwater tracking. It rejects rigs declaring a
refractive interface rather than silently producing invalid XYZ positions.

### Minimal synthetic stereo demonstration

~~~r
P1 <- cbind(diag(3),c(0,0,0))
P2 <- cbind(diag(3),c(-1,0,0))
rig <- aqt_rig_new(list(TOP=P1,SIDE=P2),units="cm")

top <- aqt_tracks(data.frame(session_id="S1",camera_id="TOP",
  track_id="top1",time_s=0,x=.5,y=.25))
side <- aqt_tracks(data.frame(session_id="S1",camera_id="SIDE",
  track_id="side1",time_s=0,x=.25,y=.25))
pairs <- data.frame(session_id="S1",id_a="top1",id_b="side1",
  time_a_s=0,time_b_s=0,fish_id="fishA")

xyz <- aqt_reconstruct_3d(top,side,pairs,rig)
print(xyz[,c("x","y","z","reprojection_rmse_px")])

occupancy <- aqt_voxel_occupancy(xyz,
  list(x=c(0,5),y=c(0,2),z=c(0,5)))
~~~

A low reprojection residual does not prove correct fish matching,
biological identity, or metric underwater accuracy.
