# Scientific-analysis workflows v1 (Milestone 03)

AquaTrajectories is an R scientific analysis layer over externally observed
fish trajectories. It does **not** invent detections, identity matches,
timestamps, behaviour labels, camera calibration or treated tanks.

The main two APIs are:

- aqt_research_analyze(): orchestrates the existing R scientific methods over
  a quality-reviewed Milestone 02 trajectory dataset.
- aqt_research_export(): emits a new, SHA-256-locked research output directory
  and serialized exact analysis object, without altering source observations.

This is an engineering and analytical-method workflow, not biological
ground-truth certification.

## Recommended research workflow

    library(aquaTrajectories)

    bundle <- aqt_research_bundle_import("research_input/top_bytetrack")
    qc <- aqt_trajectory_qc(bundle,max_gap_s=.2)
    reviewed <- aqt_qc_review(qc)

    study <- aqt_research_analyze(reviewed,
       profiles=c("movement","schooling"),
       config=list(max_gap_s=.2,min_visible_fish=2))
    print(study$diagnostics)
    print(study$movement$path_summaries)
    print(study$schooling$group_metrics)
    aqt_research_export(study,"research_outputs_m03")

For events, additionally supply an independently logged event table with
session_id,event_id,start_s,end_s. Supply the explicit clock relationship:

    event_log <- data.frame(
       session_id="S01",event_id="feeding",
       start_s=150,end_s=150)
    study <- aqt_research_analyze(reviewed,
      profiles=c("movement","events","functional"),
      events=event_log,
      config=list(
        event_clock="same_recording",
        event_outcome="speed",
        event_windows=list(baseline=c(-60,0),response=c(0,60)),
        functional_grid_s=seq(-20,20,by=2),
        max_gap_s=.2))

The clock setting is a **researcher declaration**; it does not certify
physical camera or event-clock synchronization. It is mandatory for events.

## Scientific profiles

- movement: numerical kinematics, exact gap-aware path summaries,
  eligible observations and scoped coverage.
- schooling: geometry, group centroid, pairwise distances and directional
  polarization using the *already gap-corrected* source velocities, not
  recalculated velocity derivatives that could cross excluded source frames.
  At least min_visible_fish concurrent observed fish are required.
- events: explicit recorded event windows, descriptive per-fish epoch
  statistics and aligned measurements. No causal effect is inferred.
- functional: event-relative finite grids and support/coverage. Numeric
  interpolation is limited by source-recorded interval gaps and source
  observed status. Missing values are explicit.
- experimental: independent tank design audit and an optional
  tank-level bootstrap comparison. Design must declare one unique
  session/camera -> tank/treatment row. At least two independent tanks per
  treatment arm, with baseline and response data, are required for bootstrap
  inference. A tank containing many frames or fish remains **one** tank.
- uncertainty: OPTIONAL sensitivity to researcher-declared position noise
  under fixed fish identities. This is conditional perturbation, *not* an
  empirical confidence interval or a calibrated camera error distribution.

Optional functional tank contrast and nested nlme modelling are only run with
explicit model requests and supported, sufficiently replicated data. Existing
strict functional-data requirements remain in force. Any failed model is
reported with its reason, not converted into fictional estimates.

## Configuration

Named list fields and defaults:

    list(
      max_gap_s=NULL,                 # defaults to Milestone 02 threshold
      min_visible_fish=2L,
      max_pairs=1000000L,
      event_clock="unspecified",      # declare same_recording or externally_synchronized
      event_outcome="speed",          # or step_distance
      event_windows=list(baseline=c(-5,0),response=c(0,5)),
      event_estimator="time_weighted",# or sample_mean
      event_min_points=2L,
      functional_grid_s=seq(-5,5,by=.5),
      functional_max_gap_s=NULL,      # defaults to max_gap_s
      experimental_contrast=FALSE,
      experimental_draws=199L,
      functional_contrast=FALSE,
      functional_model="none",        # or nested_nlme if eligible
      min_fish_fraction=1,
      uncertainty=list(
         enabled=FALSE,sigma=NULL,rho=0,systematic_sd=0,
         draws=30L,seed=31L))

No outcomes are silently imputed. If missing timestamps prevent timed
movement, profiles report blocked. If too few fish are simultaneously
observed, schooling reports skipped. If event timestamps or clock relation
are absent, event and functional analyses report blocked. If independent
tank replication is insufficient, inferential modelling reports blocked.

On source-derived uncertainty, setting sigma is compulsory, and the
reported 2.5/50/97.5% values are **scenario quantiles**, never sampling
confidence limits. Fish identity, missingness mechanisms and physical rig
error are not estimated by this version.

## Source-lineage and anti-pseudoreplication rules

- The caller passes an aqt_qc_review; the engine does not rerun, relabel or
  override prior manual review decisions.
- Original source rows, row-level quality ledger, accepted/excluded counts,
  physical position units, source hashes and clock declaration are retained.
- Every movement step is accepted only when its adjacent points survived
  Milestone 02 QC and correspond to adjacent recorded acquisition frames.
  This also applies to second derivatives and uncertainty scenarios.
- Group spatial calculations use the reviewed observed coordinates, while
  polarization takes velocities exclusively from gap-audited kinematics.
- Event and functional methods operate on derived measurements whose missing
  steps remain explicitly missing. No synthetic speed is created from
  skipped frame intervals.
- Experimental treatment assignment is never inferred from session names.
  The independent unit must be declared and audited.
- Unsupported analyses remain explicit in study$diagnostics; numeric
  estimates are never fabricated to fill empty figures/tables.

## Reproducible output directory

    scientific_results/
      movement/
         kinematics.csv
         path_summaries.csv
         counts.csv
      schooling/
         group_metrics.csv
         group_spatial.csv
         pairwise_distances.csv
      events/
         epoch_summaries.csv
         aligned_measurements.csv
         source_event_log.csv
      functional/
         event_grid.csv
         observed_support.csv
      statistical_models/
         experimental_design_audit.csv
      uncertainty/
         conditional_path_sensitivity.csv
      audit/
         measurement_eligibility.csv
         camera_coverage.csv
         track_coverage.csv
         profile_decisions.csv
      reproducibility/
         analysis.rds
         ANALYSIS_MANIFEST.json

Only selected and eligible profiles emit their output tables. Serialized RDS
preserves full model objects where requested and all underlying QC lineage.
All emitted files are SHA-256-accounted, a new output path is required, and
the source recordings/weights are not copied to GitHub or the report.

## Engineering acceptance

The dedicated GitHub CI workflow audits independent analytical oracles:
straight-line displacement, three-fish Euclidean geometry, acquisition-frame
gaps, numerical event-window boundaries, incomplete curves, single-fish
schooling skips, insufficient independent tanks, explicit unknown clocks,
fixed-identity sensitivity, and exact source/report digests.

The Python-to-R integration gate generates original ByteTrack, BoT-SORT,
idtracker.ai and YOLO synthetic tracker files through the Milestone 01 Python
converter; Milestone 03 consumes those exact converted bytes through native
R import, QC, review, scientific analysis and export.

These software tests do NOT replace per-study manual annotation QC or claim
validated welfare or stress measurements.
