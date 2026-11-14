# aquaTrajectories 0.1.0 (release candidate; 2026-11-14)

First versioned **engineering software** release candidate of AquaTrajectories.

## Implemented software capabilities

- 155 public R `aqt_*` functions for 2D/3D aquatic trajectories,
  movement and group metrics, event alignment, detection/tracking evaluation,
  calibrated and refraction-aware reconstruction, and uncertainty-aware
  behavioural summaries.
- Configurable Python video tracking and multiview-to-native-R pipelines,
  with camera-local video frame PTS and explicit provenance checks.
- Local 2D/3D multiview researcher explorer and opt-in simulator-tested
  physical ACI bridge.
- Independent engineering and scientific-release gates. The latter is
  intentionally fail-closed pending external validation.

## Release qualification and bug fixes

- Exact public main commit `280914063edf47edc72a2d97e5b010423992fee5`
  passed the private-user-executed **public-source-only** whole-package
  engineering audit on Windows R 4.6.1 on 2026-11-14: 41 PASS, zero FAIL,
  two nonblocking REVIEW stages.
- R testthat, built R CMD check (no errors, warnings or notes), Python
  contracts, Node explorer tests, synthetic video bundle to R, 200
  randomized trajectory checks, and six-feature engineering gate passed.
- Canonical 2D CSV import of all-NA `z` now works; canonical numeric
  time/coordinates use consistent double storage after import.
- Track identifiers retain exact zero-padded strings in canonical, YOLO,
  and idtracker.ai CSV imports; unmatched event alignment is robust.
- Release candidate adds direct synthetic regression tests for three
  previously unreferenced plotting exports:
  `aqt_plot_paths()`, `aqt_plot_joint_scene_cloud3d()`,
  `aqt_plot_tank_scene3d()`. Optional rgl rendering is conditional on
  the rgl dependency being installed.

## Explicit limitations

**Engineering gate pass is not scientific certification.** Independently
adjudicated biological identities, original video/source detector accuracy
over diverse tanks/species, physical camera exposure synchronization,
surveyed underwater XYZ and fish-length accuracy, external empirical
uncertainty coverage, real device safety, and animal welfare validation
remain outstanding. Synthetic tests must not be interpreted as evidence
that any of these empirical requirements are satisfied.

The source distribution intentionally excludes private tracking data,
original fish videos, detector weights, credentials and proprietary
third-party datasets. Public benchmark datasets must be handled under
their own licensing terms.

## Candidate status

Version 0.1.0 is **not yet tagged or released**. This candidate needs
a full exact-head qualification, manual review, and license/provenance
check before any GitHub release/tag. The 2026-11-14 passing audit pertains
to the parent source commit, not to this release-candidate commit.
