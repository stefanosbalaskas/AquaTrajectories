# Compare explicit QC policies on an existing 2D/3D trajectory dataset

This is a non-destructive sensitivity audit: all observed source rows
remain traceable in a per-policy ledger. Position coordinates, units and
time are taken exactly as supplied to \`aqt_tracks()\`. Optional
frame_id, when present, must increase strictly inside each scoped track.
Nonadjacent acquisition frames are NEVER treated as an observed movement
step, even when elapsed time is below a chosen threshold. It does not
estimate missing positions.

## Usage

``` r
aqt_qc_sensitivity(tracks, gap_limits_s, speed_limits = Inf, step_limits = Inf)
```

## Arguments

- tracks:

  A validated \`aqt_tracks\` object, in 2D image or 2D/3D tank
  coordinates.

- gap_limits_s:

  Finite positive maximum consecutive-step durations in seconds.

- speed_limits:

  Finite positive maximum speeds in coordinate units/s; Inf disables.

- step_limits:

  Finite positive maximum displacements in coordinate units; Inf
  disables.

## Value

List with \`policies\`, \`summary\` (one row per track and policy),
\`ledger\` (one row per original input observation and policy),
\`source_sha256\`, \`units\`, \`dimension\` and \`coordinate_system\`.
Policy sensitivity is NOT empirical measurement accuracy or inferential
uncertainty.
