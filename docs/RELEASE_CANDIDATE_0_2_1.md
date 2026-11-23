# AquaTrajectories v0.2.1 — exact-source publication contract

## Scope

v0.2.1 is a patch release preserving the 188 public R exports, v0.2.0
scientific safeguards and source improvements merged in PR #113.
It is not empirical verification of fish detector/tracker accuracy.

## Six fail-closed release gates

| Gate | Required evidence |
| --- | --- |
| G1 — Source/API | DESCRIPTION, CITATION.cff and NEWS identify v0.2.1; 188 documented R exports, roxygen NAMESPACE/Rd parity, exact commit identity |
| G2 — Distributable | R CMD build creates aquaTrajectories_0.2.1.tar.gz, exact SHA-256, source archive content/path safety; excludes unlicensed/private video, annotations, weights and secrets |
| G3 — Three OS | Identical R source archive independently passes zero-error/warning/note R CMD check on Ubuntu, macOS and Windows |
| G4 — Numerical/evidence | Independent 17-row source-row Python QC oracle, R/R Markdown scientific guardrail fixtures, 24 source-measured 2D/3D workloads per platform |
| G5 — Actual coverage | True covr package-test execution exactly 100% **and zero instrumented expression gaps**, with CSV/JSON audit attached; no excluded R files |
| G6 — Publication | Only after exact-main SHA passes G1-G5; create immutable annotated v0.2.1 tag and GitHub release with source tarball, evidence ZIP and checksums; no tag/release replacement |

All gates must be evaluated for the **same source SHA**. A green workflow for
a different revision is not an acceptable substitute. The workflow fails
closed if main advances before publication or the tag exists at another SHA.
The old v0.2.0 workflow is manual-only on its historical version.

## Installation and scientific boundaries

After publication, download and validate the release-specific source archive
and SHA256SUMS_v0.2.1.txt. Install with R CMD INSTALL or
`install.packages(..., repos=NULL, type="source")`. Confirm
`packageVersion("aquaTrajectories") == "0.2.1"`.
Real-video fish identity, species-level detection generalization, physical
underwater calibration, welfare inference, causal treatment effects and real
ACI device safety remain separately scoped scientific validations.
