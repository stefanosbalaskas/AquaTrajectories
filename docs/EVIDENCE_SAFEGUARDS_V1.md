# Evidence safeguards for fragmented aquatic trajectories

This module extends QC 2.0, trajectory-analysis and publication systems without
retraining detectors, inferring fish identities, correcting unknown calibration
or creating experimental replicates. Every function accepts already derived,
researcher-supplied data with explicit source-column mappings.

## Evidence levels

| Level | Eligible claims | Not established |
| --- | --- | --- |
| Observation | Detection coordinates/source measurement | Independent animal |
| Step | Eligible image-plane displacement | Physical swimming speed |
| Fragment | Continuous local software track | Persistent fish identity |
| Recording/window | Recording-level descriptive estimates | Independent tank/fish |
| Verified animal | Animal-level descriptive analysis | Treatment causality |
| Independently verified tanks | Replicated between-tank association | Randomisation/causality |

The inference-readiness audit requires at least two independently verified
tanks per treatment arm before permitting an experimental association. It
conservatively records causal_effect_certified=FALSE even when randomization
is declared, and does not weaken the existing aqt_research_analyze() gate.

## Eight implemented improvements

1. **Estimator sensitivity:** aqt_compare_specifications() reports
   pooled-step, audited-fragment-equal (when a fragment column is provided),
   software-track-ID-equal, and time-window-equal median outcomes,
   separated by explicit QC policy when supplied. Sign-reversal flags,
   denominators and original data hashes are retained.
2. **Measurement semantics:** aqt_measurement_contract() requires physical
   units, calibrated axes, a verified common spatial frame and named
   calibration evidence before *declaring* physical XYZ eligibility.
   aqt_source_3axis_preview() permits mixed axes for display only.
3. **Inference readiness:** aqt_inference_readiness() distinguishes
   observation, animal and tank evidence. Numeric-looking recording codes
   are treated as identifiers. Verified tank contrasts remain associational.
4. **Spatial coverage:** aqt_spatial_support() uses a shared grid within
   recordings, equal time-window probabilities, minimum-support flags
   and Jensen-Shannon divergence only where both phases are supported.
5. **Geometry diagnostics:** aqt_geometry_bias_audit() reports Spearman
   correlations between apparent speed and bounding-box area (plus optional
   image position and detector confidence) and coverage
   in common area strata. This is not causal adjustment.
6. **Falsification:** aqt_placebo_boundaries() produces within-recording
   time-window cut contrasts, never treating dependent cuts as p-values.
7. **Reporting:** aqt_evidence_report() derives cautious machine-readable
   statements; aqt_evidence_export() writes CSVs/PNG/Markdown and SHA-256
   manifest to a new non-overwriting output folder.
8. **Qualification:** a synthetic regression fixture and OS-matrix R script
   and R Markdown qualification cover an intentionally constructed aggregation
   sign reversal, mixed units, insufficient replication and provenance.

## Reproducible worked example

~~~r
library(aquaTrajectories)

# The installed example is SYNTHETIC, not a claim about real SmartFish fish.
source(system.file("examples", "evidence_guardrails.R",
                   package="aquaTrajectories"))

# For archival tracking outputs first run source-preserving QC:
# qc <- aqt_qc2_report(csv, gap_limits_s=c(.25,.5),
#                      units="px", coordinate_system="image")
# Select an explicit policy from qc$lineage.
# Create a separate source-linked table that includes recording,
# phase and file-local track IDs. Do not claim independently tracked fish.
# spec <- aqt_compare_specifications(steps,
#   group_col="recording", phase_col="phase", time_col="time_s",
#   value_col="speed", track_col="track_id",
#   eligible_col="step_eligible", policy_col="policy_id")
~~~

## Interpretation constraints

- Source X/Y pixels plus source-reported depth form a three-axis display,
  not a metric XYZ path. The new plotting function never calculates 3D speed.
- Window widths retain the declared input time units; do not claim seconds
  until the acquisition clock has been independently verified.
- Estimator stability applies only to the explicit specifications tested.
  Window observations can still be autocorrelated; no independent
  confidence intervals are generated.
- Shared spatial grids are consistent within each recording; comparisons
  between cameras still need independently verified geometry.
- Bounding-box association is not proof of detector-induced bias.
- Dependent within-file placebo cut fractions are not statistical p-values.
- File-local software track IDs are not verified animal identities.
- Inputs are not changed and existing output directories cannot be overwritten.

## Known-truth regression matrix

| Fixture | Expected outcome |
| --- | --- |
| Oversampled high-speed source window | Pooled positive, time-balanced negative, reversal flagged |
| Numeric-looking recording code 11025 | Preserved as character key |
| Mixed px/px/source-depth axes | Source display allowed, metric 3D blocked |
| Metric calibrated XYZ plus independent evidence reference | Explicitly declared eligible, not independently certified |
| Unverified biological units | Recording-level description only |
| Two verified independent tanks per arm | Association eligible, causal claim not certified |
| Insufficient spatial support | Divergence and entropy withheld |
| Sparse bounding-box strata | Coverage failure reported |
| Dependent within-file placebo cuts | No p-values |
| Evidence export | Hash manifest, no source mutation, no overwrite |
| Windows, Linux, macOS | R script and Rmd render successfully |

## Release gate

Release requires green package CI, roxygen documentation synchronization,
successful full-example OS-matrix qualification, and exact branch SHA
verification. Source-level review alone does not establish runtime success.
Original SmartFish recordings and the manuscript are not added to GitHub.
