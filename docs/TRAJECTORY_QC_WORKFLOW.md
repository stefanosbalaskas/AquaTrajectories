# Milestone 02: Auditable trajectory quality control

Engineering scope: video-derived 2D XY observations from the immutable
Research Bundle v1, or a matching raw table and an acquisition frame manifest.
This is transparent measurement screening, NOT independent fish-identity
certification or biological behaviour validation.

## Three separate evidence layers

1. RAW: source observations remain unchanged, with their original frame
   metadata and SHA-256 provenance. The full source is retained.
2. REVIEWED: every raw row gets a QC ledger and optional reasoned manual
   decisions. Excluded but structurally valid rows are retained with
   observed=FALSE. Ambiguous duplicates and malformed positions remain
   in the raw ledger but never enter aqt_tracks for analysis.
3. DERIVED: native aqt_kinematics and aqt_path_summary computations use
   only eligible observations, documented gaps, and declared thresholds.

## R workflow

    library(aquaTrajectories)
    bundle <- aqt_research_bundle_import("research_run/top_bytetrack")
    qc <- aqt_trajectory_qc(bundle,max_gap_s=.2,
                            max_jump_px=40,min_detection_confidence=.2)
    print(qc$row_audit)
    print(qc$camera_coverage)
    print(qc$per_track_coverage)
    reviewed <- aqt_qc_review(qc)
    result <- aqt_qc_derive(reviewed,max_gap_s=.2)
    print(result$summary)
    aqt_qc_report(reviewed,result,"new_output_folder")

Optional explicit manual exclusions:

    decisions <- data.frame(raw_row=42,decision="exclude",
                            reason="Video reviewed: fish behind pipe")
    reviewed <- aqt_qc_review(qc,decisions)

An explicit accept decision can override only quantitative quality
warnings (jump, speed, low confidence), never structural corruption,
unknown fish identifiers, duplicates, or missing position. All manual
decisions retain the source row and rationale; supplying decisions alone
does not constitute independent animal identity certification.

## Diagnostics and denominators

- Frame coverage: fraction of actual acquisition frames containing at least
  one structurally valid position or at least one eligible position. NOT
  fish-specific detection recall.
- Per-track fraction: eligible frames divided by acquisition frames between
  the FIRST and LAST sighting of the camera-local track. This does not make
  fish-absence claims outside the observed track span.
- Expected-roster fraction: only when expected_tracks explicitly declares
  individual IDs per camera/session. Missing roster entries are not inferred.
- Duplicate fish ID: all copies within a camera/frame/ID are flagged; no
  arbitrary record is chosen as correct.
- Missing position, nonfinite coordinates, out-of-image coordinates,
  frame/time mismatch, invalid confidence, and impossible IDs have separate
  flag columns.
- A long time gap, dropped frame, coordinate jump, or excessive speed
  prevents unsupported movement steps. A gap does not necessarily imply
  that either of its endpoint positions is false.
- Source timestamps are never inferred from FPS. Unknown-time bundles are
  inspectable but cannot produce time-based R movement outcomes.
- Optional manually annotated point-track scoring requires BOTH explicit
  evaluated frames (including annotated empty frames) and a positional
  matching threshold. Uses native matching, NOT official HOTA.

## Output bundle

The aqt_qc_report function writes a NEW output directory containing:
RAW_OBSERVATIONS.csv, SOURCE_FRAME_MANIFEST.csv, ROW_QUALITY_AUDIT.csv,
CAMERA_COVERAGE.csv, TRACK_COVERAGE.csv, REVIEWED_TRACKS.csv,
DERIVED_KINEMATICS.csv, DERIVED_PATH_SUMMARY.csv, DERIVED_COUNTS.csv,
QC_REPORT_MANIFEST.json, plus optional expected-roster and annotation
accuracy tables. SHA-256 digests cover the emitted CSV files. No original
videos or ML weights are copied to reports.

## Scientific limits

Movement reported in source-image pixels requires calibration before
interpreting speed in centimetres per second. Fish ID labels are scoped to
their session and camera, not certified biological individuals. Manually
declared thresholds do not diagnose stress or welfare. Frames and fish in
one experimental tank are not independent tank-level treatment replicates.

CI qualifies source format handling, deterministic geometry, exact row
accountability, gap-safe numeric calculations, and checksum-locked reports
with synthetic fixtures. It does NOT independently establish tracking accuracy.

Public functions: aqt_trajectory_qc, aqt_qc_review, aqt_qc_derive,
aqt_qc_report.
