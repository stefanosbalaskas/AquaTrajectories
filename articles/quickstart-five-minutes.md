# Five-minute quick start: tracks to scientific outputs

## Five-minute reproducible R analysis

**Audience:** first-time users familiar with basic R. **Input:**
package-generated synthetic mathematical trajectories, *not*
experimental fish videos. **Output:** plotted paths, one row per
synthetic observation, a five-track summary, and CSV files. This
exercise teaches the software contract; it does not validate real fish
identification or tank measurements.

### Step 1 — Install the published release

Use R 4.1 or later. Until CRAN acceptance is independently confirmed,
install the **published GitHub tag v0.1.2**; do not assume a CRAN binary
is available.

``` r

install.packages("remotes")
remotes::install_github("stefanosbalaskas/AquaTrajectories", ref = "v0.1.2")
library(aquaTrajectories)
packageVersion("aquaTrajectories")
```

### Step 2 — Create and inspect five synthetic trajectories

``` r

x <- aqt_simulate_tracks(n_fish = 5, n_frames = 120,
                         fps = 30, seed = 42)
stopifnot(inherits(x, "aqt_tracks"))
stopifnot(nrow(x) == 600L)
stopifnot(length(unique(x$track_id)) == 5L)
stopifnot(all(x$observed))
head(x[, c("session_id", "camera_id", "track_id",
           "time_s", "x", "y")])
```

**Expected checks:** 600 rows (5 × 120), five camera-scoped synthetic
track labels, a `time_s` column, and a 2D tank-coordinate object. Values
depend on the package’s deterministic mathematical random-walk
generator, not a real dataset.

### Step 3 — Plot and calculate motion

``` r

aqt_plot_paths(x)
movement <- aqt_kinematics(x, max_gap_s = 0.05)
summary_by_track <- aqt_path_summary(x, max_gap_s = 0.05)
stopifnot(nrow(movement) == 600L)
stopifnot(nrow(summary_by_track) == 5L)
summary_by_track[, c("track_id", "valid_steps",
                     "path_length", "mean_speed")]
```

The step threshold of 0.05 seconds includes the 1/30-second synthetic
cadence. Missing coordinates or longer gaps are not silently bridged.
The simulated position unit is **cm**, but no biological swimming-speed
calibration is implied.

### Step 4 — Align a logged intervention

``` r

events <- aqt_event_table(data.frame(
  session_id = "S01",
  event_id = "illustrative_feeding",
  start_s = 1,
  end_s = 2
))
aligned <- aqt_align_events(movement, events,
                            window_s = c(-1, 2))
head(aligned[, c("track_id", "event_id",
                 "relative_time_s", "phase")])
```

The event is an *illustrative log entry*. Alignment alone does **not**
prove a feeding response or experimental treatment effect.

### Step 5 — Export checkable outputs

``` r

aqt_export_csv(x, "synthetic_tracks.csv")
utils::write.csv(summary_by_track,
                 "synthetic_path_summary.csv", row.names = FALSE)
utils::write.csv(as.data.frame(aligned),
                 "synthetic_event_alignment.csv", row.names = FALSE)
```

These files are written to the current R working directory. Verify their
names and contents before sharing. To replace these synthetic paths with
real observations, consult the [starter CSV
formats](https://stefanosbalaskas.github.io/AquaTrajectories/articles/experiment-starter-kit.md),
[video-to-results
guide](https://stefanosbalaskas.github.io/AquaTrajectories/articles/video-to-results.md),
and [scientific capability
matrix](https://stefanosbalaskas.github.io/AquaTrajectories/articles/capabilities-and-validation.md).

### Common mistakes

| Mistake | Correction |
|----|----|
| Treating a tracker label as a permanent fish ID | An ID is scoped by camera and session until externally verified |
| Calling an arbitrary `z = 0` coordinate true 3D | Image-only observations lack measured depth |
| Computing speed across unobserved frames | Set a maximum admissible time gap and retain missingness |
| Treating every video frame as an independent replicate | Experimental inference depends on actual randomized units (often tanks) |
| Calling the HMM state “stress” without ground truth | Keep descriptive states separate from biological welfare inference |

For full API help, use the [reference
index](https://stefanosbalaskas.github.io/AquaTrajectories/reference/index.md)
and [scientific evidence
dashboard](https://stefanosbalaskas.github.io/AquaTrajectories/articles/research-evidence-dashboard.md).

The [independently reproducible v0.1.2 research
workflow](https://stefanosbalaskas.github.io/AquaTrajectories/articles/reproducible-research-release.md)
adds frozen-source QC2, publication outputs, SHA-256 provenance and a
separate Python verification oracle.
