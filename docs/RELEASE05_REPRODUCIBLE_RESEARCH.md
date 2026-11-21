# Reproducible Research Release — Priority 05

**Version:** AquaTrajectories 0.1.2. **Scope:** a qualified, source-linked
scientific-software engineering release. **Not a biological validation study.**

## Acceptance matrix

| Deliverable | Mechanism and reproducible evidence |
|:--|:--|
| Measured executed code coverage | \`covr::package_coverage(type="tests")\` through \`scripts/core2_execution_coverage.R\`; SHA-256-checked \`scripts/release05_coverage_gate.R\`, ≥80% measured source-line coverage |
| Runtime and memory baselines | \`scripts/release05_benchmark.R\`: 24 timed/allocated-memory workloads per OS (two spatial dimensions, three dataset sizes, four scientific operations), three actual iterations with independent numeric checks |
| Three-OS qualification | \`.github/workflows/reproducible-research-release-v012.yml\`: identical tests on ubuntu-latest, windows-latest and macos-latest |
| Locked source-to-report | \`research/release05/locked_trajectories.csv\`: immutable 17-row synthetic input; \`locked_expected.json\`: explicit source truth, counts, edge inclusion and reason labels |
| Native research report | \`scripts/release05_example.R\`: original QC2 lineage, explicit source and figure manifest SHA-256, 4 native journal graphics types, full standalone REPORT.md, per-fish results |
| Independent reproducibility | \`scripts/release05_verify.py\`: Python standard library (no R dependency) re-derives time/frame/observed/speed QC, 10 eligible original edges and path lengths; verifies all file hashes and checks actual figure contents |
| Full engineering gate | Strict built R CMD check (zero error/warning/note), exact generated R reference, mandatory anti-overclaim scientific gate, canonical version/citation checks |
| Versioned release | GitHub Actions release job runs **only on qualified main**, creates immutable annotated v0.1.2 tag, publishes GitHub release notes and attached proof; never fabricates a new Zenodo DOI |

## Original input and independent known answer

Source: \`research/release05/locked_trajectories.csv\`

Full original input SHA-256:

\`b940aedc80b9ca0a2355b5fcc1912cc233ecf6318044bed4d7449ca7ee0be2bc\`

All 17 raw rows remain in the QC output. Of these, 16 have observed
coordinates. The 10 policy-eligible adjacent source-row pairs are:
\`A1,A2,A5,B1,B4,B5,C1,C2,C4,C5\`.

| Synthetic fish ID | Source rows | Valid steps | Valid Euclidean length | Accepted time |
|:--|--:|--:|--:|--:|
| 0001 | 5 | 3 | 3 cm | 3 s |
| 0002 | 6 | 3 | 3 cm | 3 s |
| 0003 | 6 | 4 | 4 cm | 4 s |
| Total | 17 | 10 | 10 cm | 10 s |

- A4 is excluded because frame 3 is absent; its apparent time gap is not
  silently connected.
- B2 is unobserved; B3 has an unobserved predecessor. Both remain in the
  source ledger but yield no inferred velocity.
- C3 is 18 cm from the preceding point in 1 supplied second; it violates
  the declared 2 cm/s maximum, so it is never used as a movement edge.
- A0, B0 and C0 are first samples without previous observations; not estimable
  is not the same thing as a rejected movement.
- Source rows = 17; observed = 16; eligible = 10; rejected by policy = 2;
  not estimable = 5. Numeric truth is independently coded in Python.

## Exact reproducibility commands

From a clone at the **tagged release commit**, with R >= 4.1 and Python 3:

~~~sh
R CMD INSTALL .
Rscript scripts/release05_example.R release05-example
python scripts/release05_verify.py --out release05-example
Rscript scripts/release05_benchmark.R release05-benchmark
Rscript scripts/core2_execution_coverage.R release05-coverage
Rscript scripts/release05_coverage_gate.R release05-coverage
~~~

Python verifier requires **no third-party Python packages**.
R benchmark requires \`bench\`; coverage requires \`covr\`.
The R package already imports \`digest\` and \`jsonlite\`. Published example
outputs are new-only and transaction-staged to avoid partial data.
Run each command with a new destination; never force-overwrite evidence.

## Performance interpretation and baseline archiving

The CI artifact \`release05-performance-<operating-system>\` records measured
\`RELEASE05_BENCHMARK.csv\`, \`PERFORMANCE_README.txt\` and a SHA-256 manifest
for **each operating system**. Rows include the input object size, output
object size, elapsed median/minimum (seconds), actual \`bench\` allocations,
input digest, version, R version, fish count and observation count. These
values vary by CPU, system libraries and CRAN binary, so the script **does
not** compare raw runtime against a universal threshold or treat R allocations
as measured peak resident memory.

The \`release05-instrumented-coverage\` artifact contains actual covr
instrumented records and a separate source-SHA release gate. Absence of the
coverage tool or a numeric rate under 80% **fails qualification**.

The reproducible paper figures and research report have output-byte SHA-256
provenance, but do not promise cross-platform bit-identical vector/font bytes.
Separate previous Publication Visualization 2.0 tests establish bounded
pixel-mask reproducibility on all three operating systems.

## Negative audit and release claims

The independent checker refuses changes to source CSVs, figure input rows,
movement exclusions, report numbers, filenames, manifests and file digests.
A destructive modification of the original source cannot be relabelled
as reproduced data by changing the expected-result JSON alone, because
the original source digest and secondary known-answer edges are pinned in
the independent Python implementation.

These are **software qualification and conditional synthetic numerical
reproducibility** results, not fish biological validation, real-source ground
truth, externally calibrated clocks, camera physics, real welfare endpoints
or proof of causal effects.

A \`scientific_release\` request must still be deliberately **refused**
by the existing nine-milestone empirical scientific gate. The v0.1.2
GitHub release is explicitly labelled *engineering/reproducibility*.

## Version/DOI discipline

The existing v0.1.1 Zenodo record
\`10.5281/zenodo.24262905\` belongs to the prior release. The version
0.1.2 \`CITATION.cff\` does **not** reuse it, and a new DOI is not asserted
until a separate Zenodo record is issued and confirmed.
