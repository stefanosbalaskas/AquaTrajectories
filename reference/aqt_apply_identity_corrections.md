# Apply explicitly reviewed individual identity corrections

A correction is an instruction from a human reviewer, not an automatic
identity inference. Source identities are scoped by camera and session.
Nonoverlapping correction intervals are required for each original row.
The original ID remains available in original_track_id.

## Usage

``` r
aqt_apply_identity_corrections(tracks, corrections)
```

## Arguments

- tracks:

  An aqt_tracks object.

- corrections:

  Data frame with session_id, camera_id, source_track_id,
  target_track_id, start_s, end_s, reviewer and reason.

## Value

Corrected aqt_tracks with audit columns and correction metadata.
