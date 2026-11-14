# Wave 17 — Source-preserving fish tracking log intake

This module adds a parser and quality-control bridge for an unusual class
of tracking exports, whose header presents eight labels but each observation
has eleven comma-separated fields. The final three header labels designate
two-value XY points. A conventional `read.csv(header=TRUE)` parse does not
correctly describe this schema.

## Public APIs

| Function | Intent |
|---|---|
| `aqt_import_tracking_log()` | Read every original record, validate 11-field payload and SHA-256 provenance |
| `aqt_tracking_log_audit()` | Report fragmentation, duplicate times, boundary contact and raw-distance cutoffs |
| `aqt_tracking_log_tracks()` | Convert a source into explicitly **provisional 2D** pixel tracks |
| `aqt_tracking_log_motion()` | Compute gap-limited **pixel/s** speeds and image-plane headings |
| `aqt_tracking_legacy_replay()` | Reproduce an original historical **fixed-scale image displacement** calculation |

These functions do **not** reconstruct new 3D fish trajectories, repair
fish identities, validate water depth or infer aquarium treatment effects.

## Run locally without uploading research logs

In an installed package, use the bundled private example:

```r
library(aquaTrajectories)
options(aqt.tracking.data_dir="C:/private/fish_logs")
source(system.file("examples/legacy_tracking_private_audit.R",
                   package="aquaTrajectories",mustWork=TRUE))
```

This example creates an output subdirectory alongside your local logs
with two *aggregate* CSV summaries and, if enough valid directions
survive, one direction-rose PNG. It neither publishes raw rows nor
contacts GitHub. The development package contains **only synthetic
test rows**, not third-party fish research data.

## A reproducible intake

```r
file <- "path/to/private/BEFORE_example_tracking_log.txt"
x <- aqt_import_tracking_log(file,session_id="S001",
  camera_id="unverified",image_size=c(1920,1080),
  depth_threshold_cm=200)
qc <- aqt_tracking_log_audit(x)
print(qc)
t <- aqt_tracking_log_tracks(x,
  duplicate_policy="drop_all",drop_bad_boxes=TRUE,
  drop_boundary=FALSE)
m <- aqt_tracking_log_motion(t,max_gap_s=1,
  min_displacement_px=2)
heading <- subset(m,is.finite(heading_rad),
                  select=c(condition,heading_rad))
if(nrow(heading))aqt_plot_heading_rose(heading,bins=16)
```

No default filter in `aqt_import_tracking_log` removes rows.
`source_line` permits traceability back to original CSV lines.
Every import records a SHA-256 source hash.

## Clock, identification and measurement boundaries

**The time field is relative to each algorithmic track**, often
starting at zero for newly assigned IDs. These time values are not
video presentation timestamps and cannot align independent fish
tracks, cameras or feeding onset. `aqt_tracking_log_tracks` therefore
sets `aqt_clock_scope="per_track_relative_not_global_PTS"`.

**Fish_ID values are model-assigned fragments**, not individually
verified or biologically unique animals. A large number of IDs may
occur even in a very small tank. Matching IDs between exported files
is not evidence of physical continuity.

**Raw Depth(cm) is stored as `depth_raw_cm`, NOT as `z`**.
It can be camera-to-animal distance, another stereo quantity, or a
faulty estimator value; without original camera calibration and
definition of coordinates, the physical meaning is uncertain. The
cutoff at 200 cm reproduces an *analysis convention*, not a
biologically warranted depth threshold.

**Reported width and height are image bounding-box dimensions in
pixels.** The importer checks they agree with box endpoints
up to one pixel, detects out-of-image geometry and flags source
image-edge contact. Image dimensions are analyst-supplied, not
automatically read from a video.

**Speed in the new motion workflow is pixels per second.** In the
legacy replay, a constant conversion (`100 / 1920` nominal
centimetres per pixel) is applied only to reproduce an older
image-plane calculation. There is no perspective-aware physical
calibration, refraction correction or independently surveyed 3D
distance in that number. Original per-ID row order is preserved for
replay; repeated track clocks and time gaps remain diagnostic issues.

**No per-frame rows or multiple tracked IDs are biological
replicates.** A feeding-treatment effect requires experimental-unit
replication, intervention timestamps, allocation details and
appropriately structured inference.

## Test coverage

Tests use fabricated source data and check all of the following:
original header handling; full row count and source line numbers;
duplicate ID/time pairs; per-ID clock restart; invalid bounding boxes;
source-depth cutoff; conservatively scoped 2D tracks; motion gaps;
historical fixed-scale computation; direct handoff to the
`aqt_plot_heading_rose` visualization function.

```r
testthat::test_local(filter="legacy_tracking-real-log-ingestion")
rcmdcheck::rcmdcheck(args="--no-manual",error_on="warning")
```

Software acceptance is not independent fish detection accuracy,
physical stereo metrology, cross-camera synchronization or
welfare validation.

## What would unlock independent scientific certification?

- Original synchronized video frames and independent measured video PTS.
- Intrinsics/extrinsics, stereo baseline, underwater refraction model
  and reference survey targets with holdout XYZ coordinates.
- Human-reviewed fish identity annotations at selected frames.
- Definition and reference axis of the recorded depth estimate.
- Exact tank/session/feed schedule, events and independent tank replicates.

Until those exist, output is best considered a provisional
**real-world software interoperability and anomaly-QC benchmark**.
