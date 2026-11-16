AQUATRAJECTORIES RESEARCH STARTER KIT v1
===========================================
SOFTWARE DOCUMENTATION EXAMPLE - NOT A REAL FISH DATASET
For: https://stefanosbalaskas.github.io/AquaTrajectories/
Published software v0.1.1: https://doi.org/10.5281/zenodo.24262905

All numeric entries here are invented teaching fixtures. No real video frames,
fish identity truth, species benchmark, measured 3D, clock calibration, animal
welfare measurement, or experimental treatment outcome is supplied.

FILES:
- starter-tracks.csv: 5 synthetic camera-local tracks x 12 example samples.
  One fish03 observation is missing on purpose (both x and y blank and observed FALSE).
  Units are illustrative px; time_s is 30-steps/second synthetic time.
- starter-events.csv: one invented interval aligned to the same teaching clock.
- starter-sync-markers.csv: illustrative paired marker timestamps for two cameras.
  NOT evidence of physically synchronized recordings.
- starter-reference-boxes.csv: invented box labels; NOT independent human GT.
- starter-reference-tracks.csv: invented point ID labels; NOT independent GT.
- starter-physical-xyz-targets.csv: EMPTY HEADER ONLY. External surveyed XYZ
  references are required before physical accuracy claims.
- starter-camera-inventory.csv: schema only; NO ACTUAL MP4/CALIBRATION files.
- starter-study-design.csv: five proposed 20-minute sessions at ONE tank.
  This does not provide 5 independent tank-level treatment replicates.

R EXAMPLE:
library(aquaTrajectories)
tracks <- aqt_import_csv("starter-tracks.csv", "px", "image")
stopifnot(nrow(tracks)==60L)
events <- aqt_event_table(read.csv("starter-events.csv"))
markers <- read.csv("starter-sync-markers.csv")
clock <- aqt_sync_fit(markers, reference_camera="CAM_TOP")
kin <- aqt_kinematics(tracks, max_gap_s=0.05)
print(head(kin))

The technical input reference and ethics/validation gates:
- https://stefanosbalaskas.github.io/AquaTrajectories/articles/experiment-starter-kit.html
- https://stefanosbalaskas.github.io/AquaTrajectories/articles/capabilities-and-validation.html

Copyright (c) 2026 Stefanos Balaskas. MIT-licensed sample templates.
