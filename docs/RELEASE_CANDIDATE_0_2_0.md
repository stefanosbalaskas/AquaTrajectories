# aquaTrajectories v0.2.0 — scientific software release candidate

**Status:** candidate, not a GitHub or CRAN release until the exact-head release workflow passes and creates tag `v0.2.0`.

## Release scope

Baseline: the official immutable `v0.1.2` GitHub release with 179 exported R functions. The candidate freezes **188 public functions in 15 website reference groups**, including nine new scientific evidence APIs merged by [PR #109](https://github.com/stefanosbalaskas/AquaTrajectories/pull/109). The README/website refresh was merged as [PR #110](https://github.com/stefanosbalaskas/AquaTrajectories/pull/110).

This is an **engineering and methodological-software release**. Synthetic numerical oracles, cross-platform tests, reconstructed data workflows and real integration demonstrations do not independently validate fish identity persistence, species-wide detection performance, physical underwater XYZ accuracy, feeding causality, welfare inference, empirically calibrated intervals or actuator safety.

## Six non-negotiable release gates

| Gate | Acceptance rule | Release evidence |
| :--- | :--- | :--- |
| G1 — API/source freeze | Exact commit SHA, `Version: 0.2.0`, 188 unique exports, generated Rd/NAMESPACE parity, clean tracked sources | Candidate PR and release workflow source job |
| G2 — Numerical and QC regression | Package tests and synthetic 17-row independent Euclidean/source-row oracle; synthetic evidence example detects constructed specification sign reversal and blocks mixed-unit 3D/unsupported inference | R package checks, source oracle and evidence qualification |
| G3 — Platform qualification | Byte-identical source tarball checked on Linux, Windows and macOS, zero unexpected R CMD check errors/warnings/notes; cross-platform research-example tests and exact SHA | Three-platform workflow logs and attached result manifest |
| G4 — Provenance/privacy | SHA-256 manifest for distributable assets, no private SmartFish research files, videos, proprietary trained weights, credentials or unapproved empirical source data | Archive audit and file-extension/contents screening; manual source review still required for broader licensing |
| G5 — Metadata and interpretation | Versioned NEWS and CITATION match 0.2.0, current release notes distinguish candidate and historical release until tag exists; no fabricated DOI or empirical claim | Checked source metadata, website qualification and release notes |
| G6 — Immutable publication | Only on green exact `main` commit, create `v0.2.0` annotated tag and GitHub release; refuse changing an existing tag/release, do not touch older tags | Release workflow and GitHub release/tag API |

**Fail closed:** a failed or missing job blocks automated publication. Prior green runs for another SHA cannot substitute for this candidate's qualification.

## Audit of existing CRAN PR #79

[PR #79](https://github.com/stefanosbalaskas/AquaTrajectories/pull/79) prepares the older 0.1.2 candidate and predates the 188-export source. Do **not** merge its changed R files, Rd documentation, or stale NEWS over the current code. Its academic author metadata, `.Rbuildignore` exclusion guidance, source-tarball/as-CRAN workflow design and maintainer checklist inform this new candidate without treating its partial/stale CI as valid v0.2.0 evidence. CRAN submission is a **separate future gate**, not part of this GitHub release.

## Reproducibility

- Source: Git tag must dereference to the exact release workflow `GITHUB_SHA` and must match the published tarball provenance.
- Core numerical fixture: `research/release05/locked_trajectories.csv` is the historical, explicitly synthetic, 17-row known-truth fixture; its source hash and expected QC results remain frozen.
- Evidence fixture: `inst/examples/evidence_guardrails.R` creates synthetic input with an intentionally constructed estimator-direction reversal; it contains **no original SmartFish data**.
- Example-specific and platform-specific output files are regenerated and kept only as CI artifacts or attached release evidence.
- Author/title/ORCID reflect repository metadata. University email reachability, CRAN eligibility and third-party redistribution permissions require independent checks; CI does not certify those facts.

## Installation distinction

Until `v0.2.0` exists, `remotes::install_github("stefanosbalaskas/AquaTrajectories", ref="main")` uses unreleased development software. After publication, a version-pinned reproducible installation uses `ref="v0.2.0"`. Historical tags and version-specific DOIs must not be changed.
