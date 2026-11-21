# AquaTrajectories — Scientific Core 2.0

## Scope

**This workstream intentionally excludes detection, tracker training, video-to-3D, biological identity and claims of welfare measurement.** AquaTrajectories is a scientific numerical and visualization toolkit for researchers who already possess trajectory observations.

The historical v0.1.1 release and its DOI remain immutable. **Scientific Core 2.0 is now included in the separately qualified and published GitHub v0.1.2 release (179 public R exports).** The 171-export first-development snapshot and 155-export v0.1.1 tag were historically separate states. Zenodo DOI 10.5281/zenodo.24262905 remains specific to v0.1.1, not v0.1.2.

## 01 — Architecture and public API

- Keep `aqt_tracks` as the existing user-facing, unit-labelled 2D/3D trajectory representation. A trajectory's coordinate system, dimensions and units are not inferred from its values.
- Do not replace existing QC, numerical and report APIs. Two narrowly scoped additions are made: `aqt_qc_sensitivity()` and `aqt_figure_export()`.
- Use `scripts/scientific_core2_api_audit.py` to materialize `API_EVIDENCE_MATRIX.csv` and `API_AUDIT_SUMMARY.json` from the **exact source checkout**, including all exported function names, defining R file, matching `.Rd` aliases and test-file *text mentions*. Critically, a mention is NOT executed-code coverage or an independent mathematical oracle.
- The design avoids proliferating parallel analysis engines or assuming video data.

## 02 — General 2D/3D QC sensitivity

`aqt_qc_sensitivity(tracks, gap_limits_s, speed_limits=Inf, step_limits=Inf)` works on an existing `aqt_tracks` object with either 2D or 3D coordinates and explicit image/tank units.

- For each declared policy, report source rows, actually observed positions, potential within-track steps, eligible displacement steps, path length, supported duration and time-weighted speed.
- Retain a **per-original-row, per-policy ledger**. No original coordinates or observed flags are overwritten, and a SHA-256 fingerprint incorporates all source data plus dimensions, units and coordinate system.
- If an original acquisition `frame_id` is available, reject malformed/decreasing frames and **never bridge nonadjacent frames**, regardless of how permissive a time-based gap threshold may be.
- This is *policy sensitivity* and not statistical uncertainty, imputated movement, detection recall, or externally validated animal measurement.
- Max 64 configurations to avoid silently exhausting memory. For millions of rows use a smaller declared policy set and inspect memory limits.

Example:

```r
library(aquaTrajectories)
tracks <- aqt_import_csv("my_existing_trajectories.csv",
                          units="cm",coordinate_system="tank")
result <- aqt_qc_sensitivity(tracks,
  gap_limits_s=c(.1,.2,.5),speed_limits=c(5,10))
result$summary
result$ledger
```

For manual observation decisions and acquisition frame manifests continue to use the established `aqt_trajectory_qc()` + `aqt_qc_review()` chain; the new function does **not** override reviewer decisions.

## 03 — Stronger mathematical tests

`tests/testthat/test-scientific-core2.R` uses deterministic random geometric fixtures for rigid rotation, translation and scaling of length/speed, explicit missingness, strict 3D frame gaps, school-geometry invariance to harmless fish ID relabeling, and file-hash verification. The tests do not establish correctness for every possible numerical input or inferential model.

The existing Priority A tests remain authoritative for HMM, sparse FPCA, camera geometry, geometry, event windows and model backends. Future validation should expand executed backend comparisons and known-truth simulation coverage rather than infer numeric certification from test references.

## 04 — Journal-oriented figure exports

`aqt_figure_export(draw, directory, formats, width, height, dpi, source_file, caption)` wraps an existing base-R plotting expression and emits any selection of PDF, PNG, SVG or TIFF. Outputs are staged and content-hashed and cannot overwrite existing evidence. Optional input file is SHA-256 checked but not copied. On failure, incomplete output is deleted. No numerical results are generated or re-estimated.

```r
tr <- aqt_import_csv("my_existing_trajectories.csv",units="cm",coordinate_system="tank")
aqt_figure_export(function() aqt_plot_paths(tr),"paper_figure_01",
  formats=c("pdf","png"),width=7,height=5,dpi=300,
  source_file="my_existing_trajectories.csv",caption="Measured trajectories")
```

**Limit:** publication settings control the R graphics device and output formats. The exporter does not override the colour/legend semantics of every existing plot, and bitmap/antialiasing differences may occur across operating systems. Native rgl scenes require separate headless rendering tests and are not treated as automatically compatible with this base/grid plot wrapper.

## 05 — Reproducibility and measured performance

- `scripts/core2_benchmark.R` executes known-answer synthetic straight-line trajectories at 1,000 and 10,000 observations by default (optional 100,000 and 1,000,000), recording actual elapsed execution time, `object.size` and source/hash evidence. **Object size is not peak process memory and benchmark output is not an SLA**.
- `scripts/core2_execution_coverage.R` uses installed `covr` to actually execute package tests and produce measured coverage artifacts. It **fails** when `covr` is missing; it does not label lexical source mentions as coverage.
- Exact-source GitHub workflow checks the API inventory, new metamorphic/R tests, headless figure export and small known-answer benchmark. Strict R qualification/release checks must remain green before integration.

## Explicit acceptance and later work

- All exports have a documented source definition and correct help reference; counts must agree across NAMESPACE, pkgdown and function atlas.
- Synthetic independent geometry invariance tests and actual file-hash/device regression pass.
- 2D/3D QC sensitivity never modifies source or bridges declared frame gaps.
- Benchmark results and executable coverage are labeled as *measured* only when actually run, on pinned source and dependencies.
- Future: compare statistically comparable results against independently implemented published algorithms, strengthen CI operating-system matrix, implement meaningful visual snapshot review, test large-scale memory use and refactor any duplicated QC/reporting logic only with behavior-preserving regression evidence.

**No promise of physically validated fish, inference from videos or independently calibrated joint confidence intervals is implied by this workstream.**


## Historical first-stage CI evidence — 21 November 2026 (PRs #100–101)

The first Core 2.0 integration was merged as PR #100 following **12/12 green workflows**, including strict R CMD check with zero errors/warnings/notes; current main has **171** public R exports and v0.1.1 remains a separate immutable **155-export** tag. Python R-source/Rd audit matched all 171 exports. Deterministic mathematical known-answer and geometry invariance tests passed.

The follow-up PR #101 executed genuine `covr::package_coverage(type="tests")` instrumentation on the exact source and measured **89.1173% overall executed code coverage across 7,223 instrumented records**; this is code-execution coverage rather than independently certified statistical correctness. The same QC, mathematical and figure tests passed on **macOS** and **Windows**, with known-answer 1,000-observation benchmarks. The original Ubuntu deterministic benchmark passed for **1,000 and 10,000** observation tracks; its 10,000-observation median elapsed time was **0.024 seconds** on the recorded GitHub runner (single track, no speed service-level guarantee). R object sizes are not peak-RSS measurements.

The coverage artifact identified specific remaining internal test gaps: `.aqt_research_config` 36/53 instrumented expressions, `aqt_figure_export` 32/43, and `.aqt_publication_render` 10/16. Later development should prioritize these boundary cases, test optional PNG/PDF/SVG/TIFF device behaviour and investigate larger synthetic workloads before declaring performance or portability across all graphics backends.

These are software qualification results only. They do not certify any trajectory's biological origin, independent metrology, calibrated statistical confidence coverage or generalize across computer-vision models.


## Final v0.1.2 Scientific Core 2.0 qualification (21 November 2026)

The initial 171-export/89.1173% measurements above are **intermediate historical evidence**, not the final tagged source. Subsequent integrated milestones were merged as PRs #102–106 and released at [v0.1.2](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.2), commit `69c8f73b3690325dd9c3b0278ba449395fa251e8`, with **179 exported R functions**.

- QC 2.0: [source-row and policy audit](QC2_GENERAL_TRAJECTORIES.md), PR #103.
- Numerical Validation 2.0: [numerical oracles and metamorphic tests](NUMERICAL_VALIDATION_2_0.md), PR #104.
- Publication Visualization 2.0: [source-linked graphics and regression](PUBLICATION_VISUALIZATION_2_0.md), PR #105.
- Reproducible Research Release: [exact-source protocol](RELEASE05_REPRODUCIBLE_RESEARCH.md), PR #106; **89.33% measured instrumented R execution coverage**, **24 benchmark workloads on each of Linux, Windows and macOS**, and the locked **17-row synthetic example** with 10 eligible movement steps totaling 10 cm.

This is a qualified software-engineering and bounded synthetic numerical release, **not** external biological/physical scientific certification. The [current website release guide](https://stefanosbalaskas.github.io/AquaTrajectories/articles/reproducible-research-release.html) links to primary evidence and gives complete reproduction commands.
