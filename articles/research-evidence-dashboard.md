# Research evidence, release and validation dashboard

## Scientific evidence and release status

**Evidence date:** The bundled [scientific gate
registry](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/inst/evidence/scientific-validation-gates.json)
is dated **2026-11-12**. This page is *not a continuously updating live
benchmark database*. Check linked GitHub Actions and release records for
any newer verification.

**Published source**[GitHub
v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.1)

**Permanent
citation**[10.5281/zenodo.24262905](https://doi.org/10.5281/zenodo.24262905)

**Independent science****Not certified** as a complete biological
measurement system

### Live engineering workflow links

The badge destinations below take you to actual **GitHub Actions
history**, which may include successful, failed, skipped, queued, or
rerun jobs. A successful automated check is software evidence, not
independent underwater accuracy.

- [R
  qualification](https://github.com/stefanosbalaskas/AquaTrajectories/actions/workflows/R-CMD-check.yaml)
- [Research documentation
  website](https://github.com/stefanosbalaskas/AquaTrajectories/actions/workflows/pkgdown-research-portal.yml)
- [Full engineering and scientific-safeguard
  gate](https://github.com/stefanosbalaskas/AquaTrajectories/actions/workflows/release-candidate-full-gate.yml)
- [Source version and release
  history](https://github.com/stefanosbalaskas/AquaTrajectories/releases)
- [Open scientific
  issues](https://github.com/stefanosbalaskas/AquaTrajectories/issues)
- [CRAN candidate source review PR
  \#79](https://github.com/stefanosbalaskas/AquaTrajectories/pull/79) —
  **separate v0.1.2 candidate, not the published v0.1.1 tag**.

### Independent empirical gates

The public registry records **scientific_certified = false** for each of
these nine milestone areas. Software tests, real-format probes, and
mathematical demonstrations remain useful but do not supply the absent
external reference evidence.

| Milestone | Source registry engineering state | Remaining evidence needed |
|----|----|----|
| Fish detection | Real-source qualified | Independently reviewed held-out boxes across tanks/species |
| Fish identity | Real-source qualified | Held-out identity labels and official tracking association metrics |
| Multi-camera exposure | Software contracts passed | Measured cross-camera physical exposure pulses |
| Physical underwater XYZ | Software contracts passed | Independent surveyed target positions and error curves |
| Joint uncertainty | Software contracts passed | Empirically measured error components and held-out coverage |
| Behaviour and tank inference | Software contracts passed | External biological labels and independent tank replication |
| Unified researcher explorer | Software contracts passed | Real multiview review and independent usability/evidence evaluation |
| Physical ACI | Simulation-only | Ethics-approved device tests, hard stop, actual fish response |
| Independent science release | Software contracts passed | External replication, biological metrology, rights and scientific review |

**Do not convert these gates to passes based on synthetic tests.** New
validated evidence should be incorporated only after checking its
provenance and scope.

### Evidence to include in a research paper

Use the published package tag/DOI; identify exact versions; record
original video and reference-label hashes; document camera calibration
and timing; separate training from holdouts; report real
detection/tracking metrics; use independent tanks where appropriate; and
distinguish unconditional coverage claims from scenario-based
sensitivity. The [capabilities
matrix](https://stefanosbalaskas.github.io/AquaTrajectories/articles/capabilities-and-validation.md)
and [scientific-status
statement](https://stefanosbalaskas.github.io/AquaTrajectories/articles/scientific-status.md)
are the authoritative navigation entry points.

For publication citations, download
[BibTeX](https://stefanosbalaskas.github.io/AquaTrajectories/AquaTrajectories-v0.1.1.bib)
or use the [Zenodo record](https://doi.org/10.5281/zenodo.24262905).
