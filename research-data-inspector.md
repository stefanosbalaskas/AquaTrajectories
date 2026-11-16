# Inspect trajectory CSVs without uploading them

Phase 3 · Research laboratory · transparent evidence boundaries

# Inspect trajectory CSVs without uploading them

Read a user-selected CSV file entirely inside the browser. Validate the
canonical aquatic trajectory schema, report missing positions,
nonpositive intervals, repeated scoped timestamps and long gaps, then
export an audit summary. No server-side analysis, telemetry or file
upload is used.

## Choose input and quality rules

Local CSV (maximum 10 MB)Long-gap threshold (seconds)

0.5

Load synthetic example

Inspect selected file

Clear file and memory

No file loaded; no network calls.

Minimum columns: session_id, camera_id, track_id, time_s, x, y; optional
observed (TRUE/FALSE), z. A row with observed=FALSE should have blank
x/y/z coordinates. Missing observations remain missing: the inspector
does not interpolate.

## Calculated quality audit

Records**—**

Scoped fish tracks**—**

Unobserved rows**—**

Long gaps**—**

### Issues (up to 30 shown)

Download local audit JSON

## Research-data privacy

This inspection does not send selected file bytes to GitHub, OpenAI,
Zenodo or any backend: JavaScript reads the file object locally using
`File.text()`. It computes only schema and temporal checks; it is not an
ethics approval, automated fish identity adjudication, physical
metrology assessment or an end-to-end scientific benchmark. For official
computations, validate data with the released R functions.

[R track
validation](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tracks_validate.md)
· [R track quality
control](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_track_qc.md)
· [Local multiview review
desk](https://stefanosbalaskas.github.io/AquaTrajectories/research-multiview.md)
