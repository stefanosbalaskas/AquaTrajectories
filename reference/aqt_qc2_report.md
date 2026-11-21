# Audit general 2D/3D trajectories with QC decisions and source-row lineage

Data frames, CSV files and validated aqt_tracks are accepted. Source
column names may be mapped explicitly; milliseconds can be converted to
seconds. Physical mm, cm and m are converted by an explicit scale to the
requested analysis units, without claiming a physical calibration.
Source rows are retained and each accepted or rejected step links its
two original rows. The output contains no interpolated or
identity-corrected measurements.

## Usage

``` r
aqt_qc2_report(
  data,
  gap_limits_s,
  speed_limits = Inf,
  step_limits = Inf,
  column_map = NULL,
  units = NULL,
  target_units = NULL,
  coordinate_system = NULL,
  time_scale = 1,
  session_id = "study",
  camera_id = "sensor"
)
```

## Arguments

- data:

  Data frame, CSV path, or validated aqt_tracks object.

- gap_limits_s:

  Positive finite movement-gap policies in seconds.

- speed_limits:

  Positive speed thresholds in analysis units/s; Inf disables.

- step_limits:

  Positive displacement thresholds in analysis units; Inf disables.

- column_map:

  Optional named character vector: canonical field names
  (track_id,time_s,x,y, plus optional session_id,camera_id,z,observed,
  frame_id,source_row) mapped to source column names.

- units:

  Declared source coordinates: px, mm, cm or m. Inherited from
  aqt_tracks if omitted.

- target_units:

  Analysis units: px, cm or m; defaults to source units, except mm
  converts to cm. Inherited aqt_tracks cannot be rescaled here.

- coordinate_system:

  image or tank; inherited from aqt_tracks if omitted.

- time_scale:

  Number of seconds per source time unit (e.g. .001 for ms).

- session_id, camera_id:

  Scope labels when absent from source data.

## Value

List containing canonical tracks, policy summaries, exclusion counts,
full original source table, a source-to-step lineage ledger and hashes.
