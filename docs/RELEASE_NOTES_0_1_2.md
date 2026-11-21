# AquaTrajectories v0.1.2 — Reproducible Research Release (2026-11-21)

A software-engineering and reproducibility release for researchers who already
have timestamped 2D/3D trajectory data. **It is not independent physical,
animal identity, detector generalization, ecological/welfare or ACI
hardware-safety certification.**

## What's added since v0.1.1

- **179 public R exports**, including comprehensive general trajectory QC 2.0
  and source-row-bound Publication Visualization 2.0. The earlier released
  v0.1.1 remains untouched.
- **QC 2.0** preserves every original observation and source-row ID, separately
  records never-observed positions, first track samples, frame discontinuities,
  time gaps and policy-excluded movement steps, and exports full SHA-256 evidence.
- **Numerical Validation 2.0:** nine mathematical-method reference domains,
  with explicit numeric known answers, independent oracles, metamorphic checks,
  intentional failures and reproducible evidence.
- **Publication Visualization 2.0:** SVG/PDF/PNG/TIFF exports, generic journal
  dimensions and dpi, complete 22-public-plot gallery, six repeat-tested real
  3D scene geometries, and 4-plot pixel-level golden regression on three OS.
- **Locked 17-row trajectory-to-report example:** 3 synthetic scoped tracks;
  16 observed source positions; 10 eligible steps giving 10 cm total length;
  one skipped frame, one unobserved position and one 18-cm/s step excluded.
  Full QC ledger, PDF/PNG/SVG/TIFF publication examples, original input and
  immutable file-by-file source SHA-256 hashes are retained in its archive.
- **Independent verifier:** standalone Python 3 stdlib code independently
  recomputes source-row QC decisions and Euclidean path lengths, checks all
  original source identity, figure plotted endpoints, report numbers, output
  hashes, and refuses altered or unrecorded output.
- **Release qualification:** actual instrumented covr execution coverage,
  measured runtime and R memory allocation at three deterministic group sizes
  in both 2D and 3D, plus strict R CMD check and real execution on
  Windows/Linux/macOS. Hardware-specific times are **baselines**, not SLAs.

## Reproduce exactly

From an installed source checkout of tagged **v0.1.2**, with R, Python 3 and
R package dependencies installed:

~~~sh
Rscript scripts/release05_example.R release05-example
python scripts/release05_verify.py --out release05-example
Rscript scripts/release05_benchmark.R release05-benchmark
~~~

The source fixture is
\`research/release05/locked_trajectories.csv\`, with immutable expected
numeric outcomes in \`research/release05/locked_expected.json\`. Its file
SHA-256 is \`b940aedc80b9ca0a2355b5fcc1912cc233ecf6318044bed4d7449ca7ee0be2bc\`.

Coverage qualification additionally requires R \`covr\` to instrument the
**actually executed tests**, not lexical counts of functions mentioned in
source code; the release gate requires ≥80% measured line coverage.

The GitHub Actions qualification artifacts contain the executed coverage
matrix, 24-workload benchmark matrices per OS, the real R-produced report,
the independent verifier result, session details and original source digests.
If an external release archive is downloaded, it can be checked independently
against every nested SHA-256 manifest.

## Exact method boundaries

The benchmark computes source and output R object sizes and instrumented
**allocated bytes**, but **not peak process RSS**, GPU consumption or system
energy. Inter-machine elapsed times are not comparable without hardware/runtime
standardization. Device-driven plots may differ in rasterized pixels and
metadata across systems, within separately recorded visual regression limits.

The example's physical-looking cm units are a **declared property of its
synthetic data**, not measured underwater calibration. The time column is
explicit input, not recovered from a camera clock. The source IDs are
synthetic labels, not independently verified individual biological identity.
There is no claim of fish behaviour, stress, treatment effects, animal welfare,
external ground-truth detection accuracy or independent surveyed XYZ.

**Archive/citation:** The prior Zenodo DOI 10.5281/zenodo.24262905 identifies
v0.1.1, **not v0.1.2**. No new version-specific DOI is claimed until actually
issued and linked after publication. The new v0.1.2 GitHub tag and attached
engineering evidence provide version-specific software provenance.
