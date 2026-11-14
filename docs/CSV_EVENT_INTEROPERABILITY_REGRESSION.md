# Canonical CSV and empty-event interoperability regression (Wave 17 maintenance)

This maintenance change is based on **synthetic regression tests only**. No
privately supplied fish-tracking logs, raw video, study-derived results,
original research figures, or real fish coordinates are included.

## Fixed

1. A valid 2D aqt_tracks object stores an optional numeric z column as NA.
   aqt_export_csv() writes blank z cells; automatic read.csv() inference
   previously converted the column to logical, and aqt_import_csv() failed
   with "z must be numeric". The importer now normalizes only entirely
   missing logical coordinate columns to numeric NA.
2. Numeric-looking session/camera/track identifiers, including "0007", now
   retain their exact string representation when imported from canonical
   CSV, YOLO/Ultralytics or long-format idtracker.ai exports.
3. aqt_align_events() previously assigned scalar event metadata into
   zero-row subsets when an event's session had no observations, generating
   "replacement has 1 row, data has 0". The function now returns an
   appropriately typed zero-row event-alignment table and continues
   processing other valid events.

## Run entirely with synthetic tests

\`\`\`r
testthat::test_local(filter="csv-event-regressions")
rcmdcheck::rcmdcheck(args="--no-manual",error_on="warning")
\`\`\`

The regression file tests eleven cases:
- 2D missing-z export/import parity with zero-padded scoped IDs;
- complete 3D geometry and observed flags;
- empty but valid image coordinates;
- malformed nonmissing coordinates rejected by existing validators;
- absent-session event without crash;
- event time window without matching samples;
- mixed absent and present sessions;
- overlapping event windows;
- an entirely empty event table with stable output types;
- YOLO frame-indexed zero-padded track IDs;
- idtracker.ai long-form zero-padded track IDs.

## Whole-number coordinate storage regression (follow-up)

A subsequent strict identity check using **synthetic** image coordinates
`x=c(10,20,30)`, `y=c(15,25,35)`, and `time_s=c(0,1,2)` exposed
another CSV edge case: base R may infer integer storage from whole-number
CSV text even when the originating vectors were double. Canonical
`aqt_tracks()` now normalizes valid integer time/coordinate inputs to
double precision. This makes the in-memory schema consistent across direct
construction and CSV import without changing numeric values. New synthetic
tests assert `identical()` parity for whole-number 2D and mixed 3D
coordinates, time, and scoped IDs. This is data-type stability, not a
measurement accuracy claim.

## Boundaries

These changes only address serialization and empty-event robustness.
They do not validate tracking accuracy, source video synchrony, individual
fish identity, underwater physical calibration, or research conclusions.

A reproducible fail-to-pass comparison should use the synthetic test
file on the maintenance branch and the preceding main commit. Original
third-party datasets are not required or permitted as public fixtures.

The strict package check/CI status must be verified independently from
the code changes; a green synthetic regression is not scientific
calibration or biological accuracy certification.
