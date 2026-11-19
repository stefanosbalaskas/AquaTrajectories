# Run a unified, QC-linked aquatic scientific research analysis

Uses the source-preserving Milestone 02 review as the ONLY eligible
measurement source. No timestamps, fish identities, tank assignments or
physical calibration are fabricated. Profiles whose evidentiary
conditions are not satisfied are marked skipped/blocked with explicit
diagnostics. Event clock equivalence must be researcher-declared.
Population-level inference is limited by independently treated tanks,
not frame counts.

## Usage

``` r
aqt_research_analyze(
  review,
  profiles = c("movement", "schooling"),
  events = NULL,
  design = NULL,
  config = list()
)
```

## Arguments

- review:

  Completed aqt_qc_review from aqt_trajectory_qc.

- profiles:

  Any subset of movement, schooling, events, functional, experimental,
  uncertainty.

- events:

  Optional independent event log (session_id,event_id,start_s,end_s).

- design:

  Optional unique session/camera/tank/treatment mapping.

- config:

  Named analysis settings; see docs/SCIENTIFIC_WORKFLOWS_V1.md.

## Value

aqt_scientific_analysis with measurements, diagnostics and original QC
lineage. Model failures and unsupported profiles retain exact reasons.
