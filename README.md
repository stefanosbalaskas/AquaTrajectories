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
