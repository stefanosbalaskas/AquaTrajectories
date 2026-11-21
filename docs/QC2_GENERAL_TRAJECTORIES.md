# QC 2.0: general 2D/3D trajectory intake and row-level evidence

QC 2.0 is **not** a fish detector, identity oracle, physical calibration
or welfare validation. It extends the existing aqt_qc_sensitivity() and
validated 2D/3D kinematics without changing scientific input observations.

## Scope

- aqt_qc2_report() accepts validated aqt_tracks, a data frame or a CSV.
  Mapping of arbitrary source column names is explicit and reversible.
- Position units px/mm/cm/m and explicit time scaling are recorded. Physical
  quantities may be converted to cm or m. Pixels are never physically
  calibrated by the importer.
- Multiple gap/speed/step policies are evaluated without filling missing
  coordinates, silently connecting skipped frame IDs or changing identity.
- Each derived step links from_source_row and to_source_row; the full ledger
  preserves original row, scoped ID, time, coordinates, policy and units.
- aqt_qc2_export() writes source, canonical, summary, exclusion, policy and
  lineage tables with SHA-256 checksums, transaction staging and no overwrite.

## Example: external CSV schema

~~~r
library(aquaTrajectories)
external <- data.frame(
  specimen=rep("0007",4),clock_ms=c(0,1000,2000,3000),
  East_mm=c(0,10,30,40),North_mm=0,
  frame_id=c(0,1,3,4),original_row=c("A","B","C","D")
)
qc <- aqt_qc2_report(
  external,gap_limits_s=c(1.01,2.01),speed_limits=c(2,5),
  column_map=c(track_id="specimen",time_s="clock_ms",
    x="East_mm",y="North_mm",frame_id="frame_id",
    source_row="original_row"),
  units="mm",target_units="cm",coordinate_system="tank",
  time_scale=.001,session_id="trial_01",camera_id="top"
)
qc$policies
qc$summary
qc$exclusions
qc$lineage[,c("policy_id","from_source_row","to_source_row",
             "step_status","reason","retained_step_distance")]
aqt_qc2_export(qc,"qc2_experiment_01") # must be a NEW directory
~~~

Row C is rejected as a movement step because frame ID jumps 1->3.

## Output contract

| File | Content |
| --- | --- |
| SOURCE_ROWS.csv | Original source-table values and original row IDs, not byte-identical CSV |
| CANONICAL_TRACKS.csv | Validated, scoped trajectories in declared output units |
| QC_POLICIES.csv | Threshold IDs and time, distance and speed units |
| QC_SUMMARY.csv | Eligible step counts, accepted path lengths and durations per track/policy |
| QC_EXCLUSIONS.csv | Counts for each source-row/step decision reason |
| QC_ROW_LINEAGE.csv | Each original/previous source row, reason, inclusion and retained measurement |
| QC2_MANIFEST.json | SHA-256 file hashes and source, conversion and scientific-reference metadata |

Source-file SHA-256 is stored only when input is a CSV file.
Raw-table SHA-256 represents the imported R table, not exact bytes of a CSV.
The canonical-source signature standardizes numeric types, coordinates and
column order; equivalent aliases/conversions with identical source identity
and sampling metadata should share it.

## Acceptance criteria

1. Equivalent canonical and externally named 2D/3D tables/CSVs yield
   equal measurements, eligibility and normalized signatures.
2. Explicitly missing samples, frame skips and invalid observation flags
   cannot be interpreted as continuous fish movement.
3. Every retained step links back to exact original source rows and one
   explicit QC policy; missing/first positions are not falsely labelled
   as QC-threshold exclusions.
4. Original source tables are unchanged and leading-zero fish IDs survive.
5. Evidence is hash-audited, non-overwriting and separately exportable.
6. Synthetic group benchmarks independently verify 2D/3D centroid, nearest
   neighbor and polarization, recording measured CPU time/object sizes.

## Related validation

- test-qc2-methods.R validates irregular sparse functional sampling,
  affine clock-change invariance and independent temporal support bins;
  it does not claim statistical unbiasedness for PACE or covariance surfaces.
- qc2_group_benchmark.R evaluates 5, 20, 50 and 100 fish in both 2D and 3D.
  Elapsed times are environment-dependent; R object sizes are not peak RSS.
- qc2_plot_render_matrix.R runs the 16 native gallery plot functions and,
  when available, six true headless rgl scenes. Manifest hashes represent
  device-dependent render baselines, not pixel-perfect cross-platform parity.
- Existing research publication renderer, independent backend-agreement,
  strict R package and multiplatform tests remain required gates.

No code in this work changes the official v0.1.1 tag. A new release
must be separately qualified and versioned.
