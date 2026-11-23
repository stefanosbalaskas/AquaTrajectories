# AquaTrajectories v0.2.1 — Qualified Analytical Core and Reproducibility

AquaTrajectories is an R-first research package for pre-existing timestamped aquatic-animal trajectories. The 2D/3D analysis, source-preserving QC, publication figures, and evidence safeguards work **without a video detector or identity tracker**.

## Changes since v0.2.0

- Includes all source fixes, source refactors and targeted regression tests from [merged PR #113](https://github.com/stefanosbalaskas/AquaTrajectories/pull/113). Retains **188 documented public R exports**; no intentional API-breaking change.
- Requires **100% real covr-measured code coverage and zero uncovered instrumented expression records** on the exact release source. A complete machine-readable coverage audit is attached. Code-expression denominators may differ across revisions when redundant or unreachable expressions were removed.
- Qualifies a **byte-identical R source tarball** using zero-error/warning/note `R CMD check` on Ubuntu, Windows and macOS, the locked 17-row synthetic trajectory-to-report workflow, independent Python numerical oracle, synthetic R/R Markdown evidence safeguards and 24 measured 2D/3D workloads on each platform.

## Reproducible installation

Install the exact source archive from the versioned GitHub release, with R dependencies installed:

```r
install.packages("https://github.com/stefanosbalaskas/AquaTrajectories/releases/download/v0.2.1/aquaTrajectories_0.2.1.tar.gz", repos = NULL, type = "source")
packageVersion("aquaTrajectories")
```

Alternatively use `remotes::install_github("stefanosbalaskas/AquaTrajectories", ref = "v0.2.1")`. Verify the archive using `SHA256SUMS_v0.2.1.txt` attached to the release.

## Qualification and limitations

The evidence ZIP contains the source manifest, per-OS strict R CMD check logs, independent synthetic oracle and benchmark output, exact instrumented R execution rows and audit. These are **software tests**, not empirical fish accuracy estimates. They do not independently validate detection F1/HOTA, persistent biological animal identity, externally calibrated underwater XYZ, fish welfare, causal feeding/treatment effects, between-tank generalization or hardware-control safety.

The source excludes private SmartFish recordings, proprietary trained detector weights and other nonredistributable research data. A software track ID is not a verified biological identity.

## Immutable history and citation

The existing v0.2.0 tag, archive and publication are preserved unchanged. Cite the exact **v0.2.1** tag and the attached SHA-256 source manifest for research using this release. A historical Zenodo DOI must not be reassigned to this version; no new v0.2.1 DOI is claimed here. CRAN submission is not included in this GitHub release.
