# aquaTrajectories 0.1.2 (CRAN submission candidate; not yet released)

- Prepare the first CRAN submission from a new, distinct 0.1.2 source version;
  the existing GitHub/Zenodo v0.1.1 archive remains unchanged.
- Use a directly reachable academic maintainer email and ORCID metadata.
- Add runnable, lightweight documented examples for central R functions.
- Include a cross-platform CRAN qualification workflow building the actual
  source tarball and checking it with `R CMD check --as-cran`.
- Keep original scientific limitations: software unit tests and synthetic
  examples are not independent validation of fish identity, XYZ metrology,
  welfare conclusions, or ACI hardware safety.

# aquaTrajectories 0.1.1 (documentation and citation release)

Documentation-focused engineering-preview update to the existing 0.1.0
software. **No new independent empirical fish, underwater metrology,
welfare or hardware-control validation is claimed.**

- Publish the research website source with a guarded Pages Actions deployment;
  the existing working `gh-pages` publishing branch remains intact.
- Add the complete pkgdown reference for all 155 public R exports in 14 groups,
  plus 16 scientific-methods articles and the interactive *synthetic*
  2D/3D fish-trajectory research explorer.
- Add reproducible scientific figure galleries, original SVG illustrations,
  and website build and reference integrity tests.
- Add root `CITATION.cff` metadata (creator, ORCID, license, scope and
  software version) for GitHub's Cite menu and Zenodo archival.
- Preserve the 0.1.0 scientific safeguards: engineering qualification is not
  independent fish identity, ecological, welfare, underwater XYZ or physical
  ACI safety certification.

## Reproducibility and archival

Source releases intentionally contain no private fish recordings, human
annotation exports, proprietary model weights, secrets or private datasets.
A Zenodo DOI, if issued after the GitHub release, identifies the archived
software version and does not establish scientific validity.

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

## Historical publication status

Version 0.1.0 was published as the AquaTrajectories Engineering Preview
GitHub release on 2026-11-14. The source was engineering-qualified only,
and no independent scientific accuracy certification was claimed.
