# AquaTrajectories v0.2.0 — Scientific Evidence Safeguards

AquaTrajectories is R-first research software for existing 2D/3D trajectories, source-preserving quality control and publication-oriented analysis. It can be used **without** a video detector or identity tracker. The optional video and multiview adapters remain available with explicit scientific prerequisites.

## What changed relative to v0.1.2

- **Nine additional public R evidence functions, 188 documented exports total.** `aqt_compare_specifications()` reveals estimator-aggregation sensitivity and sign reversals; `aqt_measurement_contract()` and `aqt_source_3axis_preview()` distinguish mixed source axes from calibrated physical XYZ.
- `aqt_inference_readiness()` identifies the independently supported level of inference; `aqt_spatial_support()` checks uneven spatial coverage; `aqt_geometry_bias_audit()` reports descriptive geometry associations; `aqt_placebo_boundaries()` assesses internal recording stability without spurious p-values.
- `aqt_evidence_report()` and `aqt_evidence_export()` integrate conservative interpretation, publication figures and SHA-256 source-linked manifests.
- A synthetic known-truth regression suite and a complete R/R Markdown evidence workflow exercise those scientific safeguards on Linux, Windows and macOS.
- The frame-index research publisher now prefers the optional `svglite` vector backend on headless platforms and validates that output contains a complete SVG document.
- Source and test history for the original v0.1.2 release remain intact; no historical tag is modified.

## Evidence and reproducibility

The release qualification workflow builds a real R source tarball and runs exact-source package and evidence tests on three operating systems before creating a release. Results are recorded as GitHub Actions job outcomes, SHA-256 source manifest, synthetic reports and qualification assets attached to this version. These are **software tests**, not empirical detection-accuracy estimates.

The 17-row historical synthetic trajectory fixture and independent Python reference are deliberately retained to verify source rows, exclusion logic and numerical movement distances. The additional evidence fixture constructs known sensitivity and insufficiency cases; it is not biological data.

## Scientific limitations

No claim is made of permanent biological fish identity, externally validated fish detector generalization, automatically recovered physically calibrated underwater depth, causal feeding/treatment effects, validated welfare states, or hardware-control safety. A software track ID is not a verified fish; independent tank replication is not supplied by video frames; image pixels and reported depth are not interchangeable physical XYZ coordinates.

## Distribution, citation and history

The release source excludes original SmartFish empirical files and manuscript, third-party raw videos, private annotations, proprietary detector weights and secrets. Users should cite the exact software tag used. No new Zenodo DOI is claimed unless a separate archive for this version is actually issued.

Historic immutable versions: [v0.1.0](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.0), [v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.1), [v0.1.2](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.2). The v0.1.1 Zenodo DOI is specific to that archive and not the DOI for v0.2.0.
