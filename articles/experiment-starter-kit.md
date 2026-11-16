# Five-fish tank experiment starter kit and data schemas

## Research starter kit: one tank, five fish, two cameras

This worked example proposes **five fish, two cameras, five 20-minute
recording sessions** to illustrate data organization. The downloadable
rows are **short, invented teaching examples**, not 20-minute real
videos or calibrated 3D measurements.

**Statistical warning:** Five fish in one tank, repeatedly recorded, are
*not* five independent treatment replicates. If studying a causal
feeding or stress intervention, randomization and replication must occur
at the justified independent experimental unit (often multiple tanks),
with an appropriate hierarchical model.

### Download the files

[⬇ Complete starter kit
(.zip)](https://stefanosbalaskas.github.io/AquaTrajectories/AquaTrajectories-research-starter-v1.zip)
[Canonical example trajectories
(.csv)](https://stefanosbalaskas.github.io/AquaTrajectories/starter-tracks.csv)
[Session event log
(.csv)](https://stefanosbalaskas.github.io/AquaTrajectories/starter-events.csv)
[Two-camera sync markers
(.csv)](https://stefanosbalaskas.github.io/AquaTrajectories/starter-sync-markers.csv)
[Reference bounding boxes
(.csv)](https://stefanosbalaskas.github.io/AquaTrajectories/starter-reference-boxes.csv)
[Human ID-label schema
(.csv)](https://stefanosbalaskas.github.io/AquaTrajectories/starter-reference-tracks.csv)
[Underwater XYZ target schema
(.csv)](https://stefanosbalaskas.github.io/AquaTrajectories/starter-physical-xyz-targets.csv)
[Camera inventory
(.csv)](https://stefanosbalaskas.github.io/AquaTrajectories/starter-camera-inventory.csv)
[Tank/session design
(.csv)](https://stefanosbalaskas.github.io/AquaTrajectories/starter-study-design.csv)

**All numeric example values and fish names are synthetic.** Camera
inventory rows and physical XYZ reference rows are
schemas/demonstrations, not claims that real GoPro optics or actual
surveyed targets are supplied. Do not use the bundled “reference”
example CSVs to certify tracking accuracy: they are invented.

### Review the minimum schema

| File | Required meaning | Appropriate R interface |
|----|----|----|
| `starter-tracks.csv` | session, camera-local track ID, `time_s`, `x`, `y`, observed flag | [`aqt_import_csv()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_import_csv.md) |
| `starter-events.csv` | event `start_s` and `end_s` on the same verified time base | [`aqt_event_table()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_event_table.md) |
| `starter-sync-markers.csv` | independently paired marker IDs and camera times | [`aqt_sync_fit()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sync_fit.md) |
| `starter-reference-boxes.csv` | manually adjudicated box columns (illustrative only here) | [`aqt_detection_boxes()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_boxes.md) |
| `starter-reference-tracks.csv` | reviewed frame-scoped positions and IDs | [`aqt_tracking_observations()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tracking_observations.md) |
| `starter-physical-xyz-targets.csv` | external target survey and stereo observations | [`aqt_target_trial_table()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_target_trial_table.md) |
| `starter-camera-inventory.csv` | experiment metadata and source file lineage | Workflow metadata, not a direct package parser |
| `starter-study-design.csv` | tank/session plan and replication unit | Study design metadata, not a built-in classifier |

### Try the sample files in R

``` r

library(aquaTrajectories)
sample_tracks <- aqt_import_csv("starter-tracks.csv",
                                units = "px",
                                coordinate_system = "image")
stopifnot(length(unique(sample_tracks$track_id)) == 5L)
events <- aqt_event_table(
  utils::read.csv("starter-events.csv", stringsAsFactors = FALSE))
markers <- utils::read.csv("starter-sync-markers.csv",
                           stringsAsFactors = FALSE)
clock <- aqt_sync_fit(markers, reference_camera = "CAM_TOP")
movement <- aqt_kinematics(sample_tracks, max_gap_s = 0.05)
```

Run this after downloading the individual CSV files into your R working
directory, or extracting the ZIP. This exercise is **not a validation**
of fish detection, synchronized camera exposure or true XYZ.

### Real experiment intake checklist

1.  Record original per-camera videos, resolution, frame PTS, start
    times and unique immutable source IDs.
2.  Collect known calibration targets and a separately measured
    *held-out* underwater XYZ reference.
3.  Record physical synchronization markers across both views (not just
    file creation timestamps).
4.  Make an independent annotation plan and hold out tanks, sessions,
    and species according to the scientific claim.
5.  Identify experimental units, welfare procedures, planned exclusions,
    events and analysis timing *before* looking at effects.
6.  Preserve provenance, calibration versions, detector weights, and
    decisions that change tracker IDs.
7.  Report only measured metrics with uncertainty; clearly distinguish
    synthetic examples from study data.

Use
[video-to-results](https://stefanosbalaskas.github.io/AquaTrajectories/articles/video-to-results.md),
[multiview
3D](https://stefanosbalaskas.github.io/AquaTrajectories/articles/multiview-3d.md),
and
[capabilities](https://stefanosbalaskas.github.io/AquaTrajectories/articles/capabilities-and-validation.md)
for the next steps.
