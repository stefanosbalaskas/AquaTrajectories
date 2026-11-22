# Changelog

## aquaTrajectories 0.2.0 (Scientific safeguards and reproducible research)

This planned **software** release extends the qualified v0.1.2
analytical core. It is not a certification of empirical fish detection,
persistent animal identity, physical underwater 3D measurement, feeding
causality, fish welfare or hardware safety.

- 188 documented public R functions across 15 scientific reference
  categories, including nine post-v0.1.2 evidence-safeguard functions.
- Source-preserving estimator specification comparisons: pooled, track-,
  fragment- and equal-time-window sensitivity, numerical denominators
  and explicit direction-reversal flags.
- Explicit measurement contracts distinguishing image pixels, supplied
  auxiliary measurements and independently calibrated physical XYZ;
  mixed- axis plots are display-only until physical calibration evidence
  is supplied.
- Independent-unit readiness, spatial-support diagnostics, bounding-box/
  image-geometry associations, within-recording placebo boundaries and
  conservative source-linked evidence reporting with SHA-256 manifests.
- Portable SVG and high-resolution PNG output for frame-index reports,
  preferring optional svglite/ragg devices and verifying complete SVG
  files.
- Known-truth synthetic regressions and executable cross-platform R
  Markdown reports for the added evidence functions; no original
  SmartFish empirical recordings, analytical workbooks or manuscript are
  distributed.
- Preserve the v0.1.2 synthetic QC/independent-Python oracle and
  numerical measurement workflows as reproducible baselines; any new
  qualification statistics must come from the actual v0.2.0 source at
  its exact commit.
- Historic v0.1.0, v0.1.1 and v0.1.2 tags and their source archives are
  immutable.

See `docs/RELEASE_CANDIDATE_0_2_0.md` for six release gates and
`docs/RELEASE_NOTES_0_2_0.md` for bounded public claims.

## aquaTrajectories 0.1.2 (Reproducible Research Release; 2026-11-21)

This is a **versioned software-engineering and research-reproducibility
release**, not a claim that independently validated biological fish
identity, physical underwater accuracy, welfare or uncertainty coverage
is established.

- 179 public R exports spanning core 2D/3D movement, school geometry,
  quality-control and publication visualization.
- Complete QC 2.0 source-row exclusion lineage, original-data
  preservation and source-bound trajectory plotting; 22 public native
  plots and six headless 3D scene regression tests with four cross-OS
  pixel-golden tests.
- Independent numerical-validation matrix for nine scientific method
  groups, including synthetic oracles, metamorphic properties and
  negative cases.
- Locked **17-row synthetic trajectory-to-report** example with
  annotated missing observation, nonadjacent frame and speed exclusion,
  verified by independent stdlib Python recomputation of 10 eligible
  Euclidean steps (total 10 cm); source/input/report/figure SHA-256
  manifests.
- Actual instrumented `covr` execution coverage (80% minimum for this
  release), recorded function/source lineage and measured R
  runtime/memory allocation for 2D/3D workloads on Windows, Linux and
  macOS; the numeric correctness of benchmarks is a gate, not claims
  about speed superiority.
- Strict built `R CMD check`, three-platform benchmark/provenance tests,
  Python numerical oracle, artifact checks and release-only version
  guards.
- Publish a new immutable `v0.1.2` GitHub source release only from a
  qualified merged commit. A version-specific Zenodo DOI **must not** be
  carried forward from v0.1.1 unless a new archive record is issued.

The locked example is synthetic and publicly redistributable. Real fish
video, external ground truth, model weights and calibration data are
neither included nor fabricated. No automatic empirical-scientific
certification is implied.

## aquaTrajectories 0.1.1 (documentation and citation release)

Documentation-focused engineering-preview update to the existing 0.1.0
software. **No new independent empirical fish, underwater metrology,
welfare or hardware-control validation is claimed.**

- Publish the research website source with a guarded Pages Actions
  deployment; the existing working `gh-pages` publishing branch remains
  intact.
- Add the complete pkgdown reference for all 155 public R exports in 14
  groups, plus 16 scientific-methods articles and the interactive
  *synthetic* 2D/3D fish-trajectory research explorer.
- Add reproducible scientific figure galleries, original SVG
  illustrations, and website build and reference integrity tests.
- Add root `CITATION.cff` metadata (creator, ORCID, license, scope and
  software version) for GitHub’s Cite menu and Zenodo archival.
- Preserve the 0.1.0 scientific safeguards: engineering qualification is
  not independent fish identity, ecological, welfare, underwater XYZ or
  physical ACI safety certification.

### Reproducibility and archival

Source releases intentionally contain no private fish recordings, human
annotation exports, proprietary model weights, secrets or private
datasets. A Zenodo DOI, if issued after the GitHub release, identifies
the archived software version and does not establish scientific
validity.

## aquaTrajectories 0.1.0 (release candidate; 2026-11-14)

First versioned **engineering software** release candidate of
AquaTrajectories.

### Implemented software capabilities

- 155 public R `aqt_*` functions for 2D/3D aquatic trajectories,
  movement and group metrics, event alignment, detection/tracking
  evaluation, calibrated and refraction-aware reconstruction, and
  uncertainty-aware behavioural summaries.
- Configurable Python video tracking and multiview-to-native-R
  pipelines, with camera-local video frame PTS and explicit provenance
  checks.
- Local 2D/3D multiview researcher explorer and opt-in simulator-tested
  physical ACI bridge.
- Independent engineering and scientific-release gates. The latter is
  intentionally fail-closed pending external validation.

### Release qualification and bug fixes

- Exact public main commit `280914063edf47edc72a2d97e5b010423992fee5`
  passed the private-user-executed **public-source-only** whole-package
  engineering audit on Windows R 4.6.1 on 2026-11-14: 41 PASS, zero
  FAIL, two nonblocking REVIEW stages.
- R testthat, built R CMD check (no errors, warnings or notes), Python
  contracts, Node explorer tests, synthetic video bundle to R, 200
  randomized trajectory checks, and six-feature engineering gate passed.
- Canonical 2D CSV import of all-NA `z` now works; canonical numeric
  time/coordinates use consistent double storage after import.
- Track identifiers retain exact zero-padded strings in canonical, YOLO,
  and idtracker.ai CSV imports; unmatched event alignment is robust.
- Release candidate adds direct synthetic regression tests for three
  previously unreferenced plotting exports:
  [`aqt_plot_paths()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_paths.md),
  [`aqt_plot_joint_scene_cloud3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_joint_scene_cloud3d.md),
  [`aqt_plot_tank_scene3d()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_plot_tank_scene3d.md).
  Optional rgl rendering is conditional on the rgl dependency being
  installed.

### Explicit limitations

**Engineering gate pass is not scientific certification.** Independently
adjudicated biological identities, original video/source detector
accuracy over diverse tanks/species, physical camera exposure
synchronization, surveyed underwater XYZ and fish-length accuracy,
external empirical uncertainty coverage, real device safety, and animal
welfare validation remain outstanding. Synthetic tests must not be
interpreted as evidence that any of these empirical requirements are
satisfied.

The source distribution intentionally excludes private tracking data,
original fish videos, detector weights, credentials and proprietary
third-party datasets. Public benchmark datasets must be handled under
their own licensing terms.

### Historical publication status

Version 0.1.0 was published as the AquaTrajectories Engineering Preview
GitHub release on 2026-11-14. The source was engineering-qualified only,
and no independent scientific accuracy certification was claimed.
