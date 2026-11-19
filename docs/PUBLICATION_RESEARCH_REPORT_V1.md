# Publication reporting — Milestone 04

This workflow renders the existing, source-verified Milestone 03 scientific
analysis object. It NEVER trains a detector, assigns fish identities, runs a
new statistical estimator or fills missing observations.

## One-command R workflow

    library(aquaTrajectories)

    bundle <- aqt_research_bundle_import("research_input/top_bytetrack")
    qc <- aqt_trajectory_qc(bundle,max_gap_s=.2)
    reviewed <- aqt_qc_review(qc)

    study <- aqt_research_analyze(reviewed,
      profiles=c("movement","schooling"))

    plan <- aqt_research_figure_plan(study)
    print(plan[,c("figure_id","eligible","reason")])

    aqt_research_publish(
      study,
      directory="research_outputs/publication_v1",
      formats=c("png","pdf"),
      width=7.8,height=5.8,dpi=220,
      max_scopes=3,
      data_origin="real")

The data_origin parameter is only a researcher declaration. Using real does
not independently verify the source. Use synthetic for demonstrations.
For multi-session data, figure counts are capped with max_scopes (1..8) to
prevent accidental generation of thousands of plot files.

## Native plot reuse and scientific integrity

The report includes multiple source-supported figure families:
- Reviewed acquisition-frame coverage, not fish-level detector recall
- Eligibility and source-exclusion counts
- Original XY paths with only QC-qualified adjacent source-frame segments
- Measured per-step speeds (no unsupported interpolation)
- Native aqt_plot_school_dynamics radius-of-gyration time series
- Group polarization directly from already qualified M03 velocity vectors
- Event-epoch observed outcomes (no false treated-tank independence)
- Event-relative functional observation coverage
- Actual supported functional curves with missing values as line gaps
- Native aqt_plot_tank_changes for properly fitted tank-level comparisons
- Source-preserved time-varying functional treatment contrasts and empirically resampled bands where model eligibility is satisfied
- Conditional fixed-ID positional sensitivity scenario quantiles

No figure is emitted if an essential scientific profile is absent.
A missing/blocked figure is recorded in FIGURE_CATALOG.csv with a concrete
explanation rather than replaced by an artificial placeholder.
If a graphics device or native plot function fails, its output is marked
failed and its incomplete PNG/PDF files are removed. Other evidence remains
intact and the researcher can see the exact issue.

Vector PDF plots and high-resolution PNGs are produced using R graphics
devices. The exact precomputed source values are exported in CSV and RDS.
No source files, original videos or trained model weights are copied into
the GitHub repository or publication archive.

## Output layout

    publication_v1/
      REPORT.md
      FIGURE_CATALOG.csv
      PUBLICATION_MANIFEST.json
      analysis/
        movement/
        schooling/
        events/
        functional/
        statistical_models/
        uncertainty/
        audit/
        reproducibility/
          analysis.rds
          ANALYSIS_MANIFEST.json
      figures/
        F01_SOURCE_COVERAGE.png
        F01_SOURCE_COVERAGE.pdf
        F02_REVIEW_COUNTS.png
        ...
      tables/
        T01_QC_COUNTS.csv
        T02_PROFILE_DECISIONS.csv
        T03_CAMERA_COVERAGE.csv
        T04_INDIVIDUAL_MOVEMENT.csv (when eligible)
        T05_SCHOOL_SPATIAL.csv (when eligible)
        T06_EVENT_EPOCHS.csv (when eligible)
        T07_FUNCTIONAL_SUPPORT.csv (when eligible)
        T08_EXPERIMENTAL_DESIGN.csv (when eligible)
        T09_POSITION_SENSITIVITY.csv (when eligible)
        T10_INDEPENDENT_TANK_CONTRAST.csv (when eligible)
        T11_FUNCTIONAL_TANK_CONTRAST.csv (when eligible)
        T12_FUNCTIONAL_MODEL_FIXED_EFFECTS.csv (when eligible)

The report is standalone Markdown for straightforward scholarly review,
with figure captions, model decisions, missing data/exclusion counts,
original SHA-256, known limitations and an inventory of reusable artifacts.

PUBLICATION_MANIFEST.json signs nothing: it lists unkeyed SHA-256 hashes
for every output artifact, allowing corruption to be detected by comparison
against the archived manifest. The input research bundle should be retained
separately for stronger provenance.

## Scientific limits

- Identity labels are scoped within camera/session; this output does NOT
  establish biological identity accuracy, species, age or welfare status.
- Pixel distance is not physical centimetres. Real distance requires a
  separately validated calibration and observation geometry.
- Source event synchronization is researcher-declared, not authenticated.
- Fish/frames cannot substitute for independent experimental tank units.
- Uncertainty scenarios are conditional illustrative distributions, not
  sampling confidence limits.
- Results are descriptive unless an eligible, documented statistical model
  has already been fitted in the Milestone 03 analysis.
- The source dataset must still be independently quality checked before
  using results as evidence for a substantive fisheries research conclusion.

## GitHub engineering acceptance

The dedicated CI requires:
1. Independent numerical source and QC oracles remain unchanged.
2. Deterministic plot planning records both complete and withheld figures.
3. Actual PNG and vector PDF files are nonempty and have valid magic bytes.
4. Scientific result tables match the stored original analysis outputs.
5. Figures never reconnect excluded/missing-frame movement steps.
6. Complete output SHA-256 digests and report source IDs match the input.
7. Unknown source clocks block time-based graphics.
8. Python-produced YOLO, ByteTrack, BoT-SORT, idtracker.ai source exports
   successfully pass through R review and actual report generation.

The GitHub tests use synthetic fixtures to prove software behaviour. They
do not claim empirical accuracy of the tracker on new real recordings.
