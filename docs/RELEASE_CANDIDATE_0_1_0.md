# v0.1.0 — release-candidate acceptance checklist

**Release type:** engineering software distribution, **not**
independent biological, physical metrology, animal welfare or ACI hardware
certification.

## Source and provenance

- [ ] Confirm branch head/PR merge commit SHA and `DESCRIPTION Version: 0.1.0`.
- [ ] Audit all tracked source files for embedded private user recordings,
      confidential coordinates, secrets, third-party annotations, licensed
      weights, or other nonredistributable content. Filename heuristics alone
      do not establish legal clearance.
- [ ] Review MIT license, attribution, public dataset license obligations,
      and installed package namespace/manual consistency.

## Mandatory software qualifications — run on the SAME source commit

- [ ] R files parse; 155 public R exports documented.
- [ ] Full `testthat` suite, including synthetic plots and optional `rgl`
      headless tests when `rgl` is available.
- [ ] Built `R CMD check --no-manual`: **0 errors, 0 warnings, 0 notes**;
      roxygen-generated NAMESPACE/man show no drift.
- [ ] Isolated source package install and exact-version namespace check.
- [ ] Python syntax compilation and **all** standard-library contract tests.
- [ ] Node source syntax and complete explorer unit test suite.
- [ ] Python mock video runner → R MOT/PTS/SHA-256 integration fixture.
- [ ] Six-feature strict software gate returns success, with genuine
      synthetic 2-/3-camera XYZ and no-detection tests.
- [ ] Scientific release gate returns **exit 2** as the intended refusal.
- [ ] Randomized synthetic movement/data-integrity tests; confirm results.
- [ ] Inspect executed R coverage (by line and export where available);
      skipped optional graphics must be disclosed, not called executed.
- [ ] Verify exact file digests and confirm a clean release checkout.
- [ ] Investigate every mandatory failure before tagging the release.

## Release packaging and communication

- [ ] Re-run the entire AquaTrajectories v3 audit against the release
      candidate **PR head**, not the already-qualified parent main SHA.
      Update the runner's pinned SHA and required version. Preserve its
      full outputs and logs in a private evidence archive.
- [ ] Verify GitHub Actions checks on the current source SHA; queued jobs
      are **not** green checks. Accept documented Windows evidence
      separately, but do not misrepresent hosted CI.
- [ ] Review `NEWS.md`, `README.md`, release source archive, and optional
      GitHub release draft. Make a tag only after the merged source is
      requalified at its final SHA.
- [ ] Publish code and synthetic examples only. Do not publish the
      original researchers' fish tracking logs or study-derived reports.

## Research/physical claims intentionally not approved

- [ ] Blind independent fish detection/tracking ID ground truth and
      official HOTA/IDF1 across held-out cameras/tanks/species.
- [ ] Independently measured underwater 3D/length targets and camera
      exposure synchronization.
- [ ] Independently checked joint uncertainty calibration on holdout tanks.
- [ ] Expert-labelled behaviour/welfare outcomes from replicated tanks.
- [ ] Hardware safety, ethics and real device testing for ACI.
- [ ] External scientific reproducibility certification.

Those six scientific requirements **remain open** and must not be
silently converted to passed because the software release succeeds.
