# Existing-data numerical and plotting qualification (proposed milestone)

## Purpose

AquaTrajectories can analyse existing trajectory tables independently of
fish detection or identity tracking. This script qualifies **software arithmetic
and figure rendering** for researcher-supplied data, not biological ground truth.

Required source CSV columns: session_id,camera_id,track_id,time_s,x,y.
Optional columns: z,observed. Coordinates are explicitly declared as
image pixels or physical tank units. The clocks must be physically verified
if time_s is to be interpreted as seconds for fish speed or event inference.

## RStudio usage

After installing the branch/release containing the script:

~~~r
source(system.file("scripts", "aqt_qualify_existing_csv.R",
                   package = "aquaTrajectories"))

aqt_qualify_existing_csv(
  input_csv = "C:/Users/YourName/Documents/fish_positions.csv",
  output_dir = "C:/Users/YourName/Documents/aqt_qualification_run_001",
  units = "px",
  coordinate_system = "image",
  max_gap_s = 0.2
)
~~~

The output directory must not exist and its parent directory must exist.
No original data is overwritten. The outputs are:
QUALIFICATION_REPORT.json, KINEMATICS.csv, PATH_SUMMARY.csv,
GROUP_SPATIAL.csv and OBSERVED_2D_PATHS.pdf (for 2D only).

A separately written base-R oracle checks that per-frame step lengths,
timestamps, per-individual path totals, and durations agree with the package.
The generated PDF confirms that the native plotting function renders but
does not prove that the input fish positions are biologically accurate.
Numeric positions marked observed=FALSE are masked from plotted paths.
No 3D scene is automatically produced by this headless script.

## Analytical tests

The automated test file contains independent known-answer fixtures for:
- CSV import preserving leading-zero identifiers.
- 3–4–5 movement paths, stationary paths, and missing observations.
- Exact speed, acceleration, path length, mean speed and duration.
- 3D 5–12–13 displacement across a 2-second interval.
- Three-fish 3–4–5 triangle, centroid and radius of gyration.
- PDF output and malformed-input/overwrite refusal.

These are **synthetic analytical reference examples**, not real animals.
The code is submitted as a qualification suite; its pass/fail status must
be assessed by R CMD check on the actual PR head.

## What this does not certify

Fish identities, detection/tracking accuracy, genuine timestamp provenance,
physical underwater XYZ, behavioural states, welfare, uncertainty interval
coverage, 22/22 plots or all 155 R exports are **not** established by this work.

No original videos, annotated datasets, detector weights, or manuscripts are
committed to the repository.
