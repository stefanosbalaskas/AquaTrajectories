# AquaTrajectories Website v2 — qualification and evidence protocol

Version scope: public website on main/gh-pages after merging PR #87. The scientific R software release remains archived as **v0.1.1 (DOI 10.5281/zenodo.24262905)**. Browser modules are website functionality; they are not silently included in the frozen Zenodo R release.

## Independent gates

| Gate | Executable evidence | Acceptance criterion | What it does NOT certify |
|---|---|---|---|
| R ↔ JavaScript computational parity | scripts/create_browser_parity_fixtures.mjs and scripts/verify_browser_r_parity.R | Exact released R API agrees on five refractive ray cases (2e-5 cm), five velocities (1e-9) and four group polarization examples (1e-9). | Empirical camera calibration, fish identity, real underwater XYZ or error coverage |
| Local CSV/provenance integrity | scripts/test_research_local.mjs; scripts/test_convert_digi4eco_cvat.py | Missingness, scoped IDs, duplicate timestamps, original source PTS, DTD rejection, CVAT outside and occluded flags are tested | Source-author labels are not validated model predictions |
| Memory/performance | scripts/test_local_perf_budget.mjs | 20,000 invented CSV rows parse and QC within 15 s, net heap under 220 MiB on CI runner | Real video decoding throughput or all mobile device memory conditions |
| Chromium browser interactions | tests/browser/research-labs.spec.mjs; scripts/browser.playwright.config.mjs | Four real labs render and their controls respond; synthetic XYZ recomputes, data audit downloads, multiview seeks, no user-file non-GET requests | Human visual QA or external hardware synchronization |
| Browser WCAG checks | Axe-core in Playwright browser tests | No machine-detectable violations under selected WCAG 2.0/2.1/2.2 A/AA tags | A full accessible-technology usability study |
| WebAssembly R | webR 0.6.1 network runtime test with explicit user consent | Real in-browser base R produces console results; optional v0.1.1 function sources are fetched from the same origin, sourced, and actual released kinematics/group-metric functions execute | Installing/building the full aquaTrajectories package for WebAssembly |

The existing website workflow first builds an **immutable site preview artifact**. A dependent browser job downloads precisely that artifact and must succeed before either GitHub Pages publishing job may run. No browser test gets a different source tree from the publication artifact.

## Exact native-source webR subset

The following website source files are byte-for-byte copies of the corresponding source files in the **published v0.1.1 software tag**:

- pkgdown/assets/native-v0.1.1-tracks.R → R/tracks.R (published Git blob dd9dce3c5031a9d8682aeb2869532b3a65ee8008)
- pkgdown/assets/native-v0.1.1-kinematics.R → R/kinematics.R (published Git blob 6bb61de6a78e78013f912204e84edf51e2a0bf40)

The website CI also compares the copies against R/tracks.R and R/kinematics.R on its checked-out release-compatible main branch, failing if they differ. The public website requests these source files **only after the user explicitly initializes webR and requests the native-source option**. They are written into the webR virtual filesystem and loaded through the R source() command.

This is **execution of actual archived functions**, not a complete package compiled for WebAssembly, and it does not test native optional dependencies such as rgl, nlme or fdapace. Running webR downloads the interpreter from an external version-pinned public CDN; it does not send user research CSV or video bytes to that CDN.

## Real original-video source workflow

Primary real dataset: DIGI4ECO Underwater Fish Tracking Dataset, DOI 10.5281/zenodo.20701225, **CC BY 4.0**, created by Sandra González-Villà, Dylan Burns Font, Jacopo Aguzzi and colleagues (2026). Credit the full author list available from the Zenodo record when redistributing derivatives.

The website article **real-fish-data-walkthrough.html** describes downloading original MP4 video and original CVAT 1.1 annotation XML from Zenodo. The offline converter scripts/convert_digi4eco_cvat.py requires a separately extracted original decoded-frame PTS CSV; it produces local source-frame, source-track and source-box tables plus SHA-256 provenance. It does **not** generate detector/tracker predictions, copy original MP4 into GitHub, create 3D coordinates or imply blind human identity adjudication.

CI uses a **fictional three-frame XML fixture** to test the converter; it never treats that as having processed the actual Zenodo video. Actual dataset execution requires the original files and separate written empirical records.

## Privacy and performance audit

- Client-side inspector and multiview reader use browser-selected File objects, local parsing and browser object URLs. No application server endpoint is provided.
- The Chromium suite intercepts outgoing requests and rejects non-read-only requests during user-file operations.
- Local CSV intake is bounded to 10 MiB per selected CSV and 200,000 records in the generic parser; the multiview specialized parser rejects inputs beyond 50,000 source frames.
- The 20,000-row synthetic stress test is a regression budget, not a guarantee for every machine or dataset.
- A user can clear selected data and object URLs from the current viewer page state. The browser or operating system may maintain its own caches; no claim of secure data erasure is made.
- The webR runtime is a **separate explicit network operation** to load published R WebAssembly from the pinned CDN. No selected source fish videos are supplied to webR by these demos.

## Manual tests that remain relevant

1. Test screen-reader descriptions, keyboard focus sequences and download announcements with NVDA/VoiceOver/TalkBack; automated axe tests alone are not full WCAG certification.
2. Check original local MP4 codec/PTS seeking in Chrome, Firefox, Safari and on resource-constrained mobile hardware.
3. Test source-file clearing, browser reloading and long-running webR failure modes in real user sessions.
4. Review the real downloaded DIGI4ECO video and source annotation overlays against the original source by qualified annotators.
5. Execute a predeclared held-out detector/tracker benchmark with genuinely frozen outputs to measure accuracy; do not treat these website demonstrations as evidence.

## Reproduction

CI commands:

- node scripts/create_browser_parity_fixtures.mjs
- Rscript scripts/verify_browser_r_parity.R
- python3 scripts/test_convert_digi4eco_cvat.py
- node scripts/test_local_perf_budget.mjs
- npx playwright test --config scripts/browser.playwright.config.mjs

R qualification requires installing the checked-out R package locally; browser qualification requires the generated pkgdown site, Node, the Playwright dependencies and Chromium. Browser and R reports are retained as downloadable GitHub Actions artifacts where generated.

**Scientific publication boundary:** software correctness and benchmark provenance are distinct from external field validity. No synthetic example, low ray residual or source-author annotation by itself proves physical underwater XYZ accuracy, cross-camera biological identity, welfare or intervention causality.
