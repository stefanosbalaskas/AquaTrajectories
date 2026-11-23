# Research evidence, release and validation dashboard

## Scientific evidence and release status

**Evidence snapshot: 23 November 2026.** The current published software
is [AquaTrajectories
v0.2.1](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.2.1).
The source archive, qualification ZIP and SHA-256 checksums are
versioned release assets. This page distinguishes cross-platform
**software qualification** from the later **M10 real-data R analytical
replay**, and both from biological or physical validation.

**Official release**v0.2.1 · 188 exported R functions

**Measured R coverage**100.0000% instrumented expressions · 0 uncovered

**M10 frozen-input R replay**65/65 R–Python comparisons · Windows

### 1. What the exact v0.2.1 source release establishes

The released source archive passed strict `R CMD check` without errors,
warnings or notes on **Ubuntu/Linux, Windows and macOS**. The release
gate also verified **188 documented R exports**, **100.0000%
covr-measured instrumented R expression coverage** (zero uncovered
expressions), a frozen **17-row synthetic** QC-to-report example
independently recalculated by Python, and 24 measured 2D/3D workloads
per operating system. Source and output hashes and executable
qualification details are attached to the [official v0.2.1
release](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.2.1).

These are release-quality and numerical checks. **100% code coverage is
not 100% fish detection, biological accuracy, uncertainty calibration or
proof that every statistical assumption holds.** The earlier [v0.1.2
reproducibility
protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.2/docs/RELEASE05_REPRODUCIBLE_RESEARCH.md)
describes the historical introduction of the 17-row example and earlier
performance baselines; the current-release qualification is that of
v0.2.1.

### 2. M10: exact-version historical M07–M08 R analytical replay

The M10 audit used the **actual published v0.2.1 R package** on a
Windows 11/R 4.6.1 environment, reading frozen M07 analytical source
tables and archived M08 reference-matching records. It authenticated the
published R source archive and original input hashes, recomputed the
specified source-linked R movement and measurement summaries, and
compared them against an independently implemented Python calculation.

| M10 property | Verified outcome | Important boundary |
|:---|---:|:---|
| BrackishMOT original recordings | 5 sequences; 868 acquisition frames | Five source sequences, not independent tanks |
| Publisher-reference fish observations | 6,621 | Publisher source labels, not new blinded adjudication |
| External model/tracker observations | 2,830 | Frozen outputs, not newly rerun YOLO/ByteTrack inference |
| IoU 0.50 reference positions matched to tracked boxes | 374 / 6,621 (5.65%) | Conditional track-output reference coverage |
| Original adjacent reference fish-ID steps | 6,498 | Original denominator retained |
| Same-model-ID eligible adjacent steps | 265 / 6,498 (4.08%) | Most reference movement is not evaluable from model tracks |
| R–Python comparisons on exact v0.2.1 | **65 / 65 PASS** | 59 matching numerical values; six jointly undefined |

The local replay reproduced the archived 65-row numerical comparison
ledger exactly. It **did not retrain a detector, rerun model inference,
correct source identities, estimate physical swimming speed or certify
underwater XYZ**. Conditional position and step errors are based on the
matched minority, not the whole reference fish population. Read the
[public M10 scope
statement](https://github.com/stefanosbalaskas/AquaTrajectories/blob/main/docs/M10_ANALYTICAL_V021_REPLAY_SUMMARY.md)
and the [M08 measurement
protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.2.1/docs/BRACKISH_MEASUREMENT_VALIDATION_M08.md).

The M10 local evidence audit and original third-party media/model assets
are **not deposited as a public empirical source archive on this
website**. The repository provides scripts, protocols and
source-qualified software; a full independent source-based replay
requires the original third-party research inputs with their own licence
and provenance conditions. The detailed audit is not claimed to be a new
external biological ground-truth study.

### 3. Capability and external-evidence boundaries

| Scientific claim | What is qualified | What remains required for a stronger claim |
|:---|:---|:---|
| Native R movement and QC calculations | Exact v0.2.1 source tests and bounded real analytical replay | Application-specific measurement quality and assumptions |
| External fish detector/tracker | Published-reference comparison of frozen model outputs | New heldout recordings, prediction-blind reference review, identity evaluation |
| Fish biological identity | Source-labelled track-ID arithmetic | Independently adjudicated persistent fish identities |
| Camera synchronization | Tested affine-clock and holdout software interface | Measured exposure/synchronization evidence for each rig |
| Underwater 3D XYZ | Conditional refractive geometry algorithms and synthetic tests | Independently surveyed underwater XYZ targets, held-out calibration configurations |
| Uncertainty and school/behaviour estimates | Sensitivity and output software methods | Measured error distributions, adequate observational support and independent experimental units |
| Feeding, stress or welfare effects | Descriptive movement/event interfaces | Ethological/physiological criteria and ethically approved, replicated designs |
| Hardware/ACI actuation | Simulated and guarded software interfaces | Independently qualified physical interlocks and animal-research safety procedures |

The original [scientific validation
registry](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.2.1/inst/evidence/scientific-validation-gates.json)
records earlier external-evidence gaps; software release progression and
the M10 arithmetic replay do not silently promote any unverified
biological/physical claim to certification.

### 4. Reproduce and cite the appropriate evidence

- [Current v0.2.1 source release, source SHA-256 checksums and three-OS
  evidence](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.2.1)
- [Current reproducibility
  walkthrough](https://stefanosbalaskas.github.io/AquaTrajectories/articles/reproducible-research-release.md),
  [five-minute synthetic quick
  start](https://stefanosbalaskas.github.io/AquaTrajectories/articles/quickstart-five-minutes.md),
  and [capability/validation
  matrix](https://stefanosbalaskas.github.io/AquaTrajectories/articles/capabilities-and-validation.md)
- [Historical M07 real-source
  parity](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.2.1/docs/M07_REAL_DATA_PARITY_AUDIT_20261120.md)
  and [M08 reference
  measurement](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.2.1/docs/BRACKISH_MEASUREMENT_VALIDATION_M08.md)
- [M09 physical/biological external-validation
  requirements](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.2.1/docs/M09_EXTERNAL_VALIDATION_READINESS.md)
- [Research website build, browser qualification and deployment
  history](https://github.com/stefanosbalaskas/AquaTrajectories/actions/workflows/pkgdown-research-portal.yml)

**Publication practice:** cite the exact software tag used in an
analysis; preserve source input hashes, full-denominator exclusion
records, camera/track scopes and measurement units; distinguish
synthetic figures from real observations. A GitHub source release is not
a CRAN publication or an independently peer-reviewed paper.

**DOI boundary:** Zenodo
[10.5281/zenodo.24262905](https://doi.org/10.5281/zenodo.24262905)
belongs to **historical v0.1.1**, not v0.2.1. No new v0.2.1 DOI or
accepted MDPI article is claimed.
