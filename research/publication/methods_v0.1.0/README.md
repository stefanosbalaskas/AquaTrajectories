# AquaTrajectories — methods manuscript and independent validation dossier
**Dossier version:** `methods-v0.1.0` · **Prepared:** 2026-11-16 · **Status:** protocol and manuscript DRAFT, not an empirical scientific certification.

This is a **versioned, source-traceable publication workspace**. It is not a new package release, not a CRAN submission, and not a claim that its planned external validation has been carried out.

**Pinned paper baseline:** released R package `v0.1.1`, commit `43101800087a18d0942da4d03e21ea47099cb7a9`, DOI [10.5281/zenodo.24262905](https://doi.org/10.5281/zenodo.24262905). Current website/main engineering snapshot used to inspect supporting documentation: `938433baac91684a2cf5f68d136bcd7fb2a3237c`. The distinct first-CRAN candidate `0.1.2` and PR #79 are **not** the published software version used in this dossier.

## Contents

| File | Role |
| --- | --- |
| [MANUSCRIPT.md](MANUSCRIPT.md) | Full journal-agnostic architecture/methods paper, with result placeholders explicitly blocked |
| [REGISTERABLE_PROTOCOL.md](REGISTERABLE_PROTOCOL.md) | Prospective external benchmark, calibration, annotations, ethics and frozen splits |
| [STATISTICAL_ANALYSIS_PLAN.md](STATISTICAL_ANALYSIS_PLAN.md) | Metric definitions, contrasts, uncertainty, missingness, clustering and decision rules |
| [REPORTING_BLUEPRINT.md](REPORTING_BLUEPRINT.md) | Empty table and figure shells with no fabricated scientific findings |
| [DATA_DICTIONARY.md](DATA_DICTIONARY.md) | Minimum fields for independent heldout evidence and provenance |
| [LITERATURE.bib](LITERATURE.bib) | Checked foundational scholarly sources and package citation |
| [SOURCE_AND_CLAIM_LEDGER.md](SOURCE_AND_CLAIM_LEDGER.md) | Which claims are verifiable now versus still unsupported |
| [SUBMISSION_GATE.md](SUBMISSION_GATE.md) | Must-pass release and authorship/ethics/source review |
| [manifest.json](manifest.json) | Fixed software baseline, artifact inventory, data-gate statuses |
| [schemas/](schemas/) | **HEADER-ONLY** CSV schemas, no fabricated experimental measurements |
| [scripts/](scripts/) | Standard-library reproducibility manifest audit and archive builder |
| [tests/](tests/) | Fail-closed regression tests for the protocol package |

## Start with source, not a synthetic benchmark as “ground truth”

1. Read the repository's [scientific gate registry](../../../inst/evidence/scientific-validation-gates.json) and [issue #51](https://github.com/stefanosbalaskas/AquaTrajectories/issues/51).
2. Read `MANUSCRIPT.md` and `REGISTERABLE_PROTOCOL.md`. The manuscript's empirical Results section remains **NOT AVAILABLE** until the actual independent sources are acquired and the heldout design is fulfilled.
3. Install Python 3.11+ for the **stdlib-only** bundle integrity tool, run `python research/publication/methods_v0.1.0/scripts/verify.py --mode protocol`. Protocol mode validates structure; it never marks scientific evidence as accepted.
4. Run `python -m unittest discover -s research/publication/methods_v0.1.0/tests -v` for self-tests.
5. To generate a deterministic, privacy-safe ZIP containing only this dossier: `python research/publication/methods_v0.1.0/scripts/build_bundle.py`. Do not add real videos, restricted weights, third-party ground truth, credentials or unlicensed assets.
6. Register the actual protocol **before looking at the independent heldout results**. A repository file is *not* a registration; record a real registration URL and timestamp later.
7. Fill the evidence ledger and analysis outputs only from reviewed real data, verify original hashes, and re-run the evidence gate. The tool intentionally rejects empty real-evidence dossiers.

## Claims and archival discipline

- **Software is available:** 155 exported R functions at the published v0.1.1 release, with R/Python/JS integration and software CI.
- **Real-data feasibility exists:** Oxford original fish-video inference/ByteTrack and Fraunhofer source-domain work (see code/docs); published-source or partially model-assisted labels are **not** prediction-blind independent ground truth.
- **Independent empirical certification is not available:** physical underwater surveyed XYZ, true cross-camera exposure calibration, comprehensive blinded fish-identity labels, calibrated joint uncertainty coverage, replicated fish behaviour/welfare effects, and physical ACI device safety.
- **The bundled schemas contain headers only.** No real fish, tank, trial, welfare, or 3D benchmark measurements are included.

**Authorship, journal venue, funding, software contributions, AI-assisted drafting disclosure, dataset permissions, ethics and final quantitative results require human verification.** This is an internally usable protocol and manuscript foundation, not permission to submit an unverified paper.
