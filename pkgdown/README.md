# AquaTrajectories documentation portal

This directory holds **website source**. The project's existing scientific protocol files under `docs/` are never used as generated output.

- `pkgdown/index.md`: independent landing page (preserves GitHub README).
- `_pkgdown.yml`: Bootstrap 5 theme, all 155 exported R functions in 14 curated categories, article routing.
- `pkgdown/extra.css`: accessible navy/teal brand.
- `pkgdown/assets/*.svg`: original illustrations; conceptual, not observations.
- `pkgdown/assets/starter-*.csv`: downloadable synthetic or schema-only research starter files.
- `pkgdown/assets/AquaTrajectories-v0.1.1.bib`: version-specific citation export.
- `pkgdown/assets/synthetic-explorer.*`: standalone browser-only invented fish paths and projections; never real observations.
- `vignettes/articles/*.Rmd`: website-only articles, a 5-plot source-derived publication workbook, and runnable synthetic plots.
- `site/`: generated output, not committed to version control.

From a source checkout:

```r
install.packages(c("pkgdown", "rmarkdown", "knitr", "yaml"))
source("scripts/check_pkgdown_reference.R")
pkgdown::build_site(examples = FALSE)
```

GitHub Actions builds a preview artifact on PRs. On a successful `main` build, a separate guarded job copies the **exact smoke-tested site artifact** to the existing `gh-pages`/(root) branch, which is the current GitHub Pages publishing source. PRs never deploy. The alternative GitHub Actions Pages deployment job remains opt-in and disabled until its repository setting and Pages source are deliberately changed. Review the preview artifact and scientific limitation language before merging.

Neither the website nor any generated figure is evidence of independently certified biological measurement, underwater calibration, or ACI hardware safety.

## Website-only research improvements

Do not change the CRAN candidate or existing GitHub release to publish website content. The homepage shows the current *published* GitHub version, v0.1.1. The CRAN candidate 0.1.2 is not advertised as released. The new pages are: five-minute onboarding, capability matrix, video-to-results workflow, tank experiment starter kit, identity/occlusion explanation, and evidence dashboard. All illustrative files are synthetic, metadata examples, or empty schemas. Maintain source Rmd and pkgdown/index.md as the authority; never hand-edit generated HTML on gh-pages.

## Phase 1 usability

Main-branch website source adds visible lab/experiment routes, 22 direct plot-to-code/function help/version-pinned implementation links, accessible deep-link expansion and keyboard focus styles, and a source-only metadata normalizer after pkgdown builds. Review the PR preview artifact; the official v0.1.1 software release is unchanged.

## Phase 2 scientific teaching (website only)

Four static browser labs provide deterministic **synthetic** object detection/track-ID didactics, vector/school/clock mathematics, three adjustable SVG plotting previews plus version-pinned R code recipes, and downloadable planned experiment protocols/blank CSV manifests. The website does not claim official HOTA/IDF1, independent video performance, live animal welfare or physical XYZ calibration. Source files are in `pkgdown/assets`, connected from the home page and the new `vignettes/articles/scientific-teaching.Rmd`. Node teaching-core regression tests run in the pkgdown CI build before smoke testing.

## Phase 3 research laboratory (website only)

New `research-*.html` modules in pkgdown assets demonstrate single-interface above-water refracted rays, opt-in pinned webR v0.6.1 with GitHub Pages PostMessage worker, source-frame-matched local multiview video + XYZ inspection, and CSV-only on-device QC. The linked `research-laboratory.Rmd` discloses scientific boundaries. Pure numerical and CSV validation functions have deterministic Node regression tests. Browser workflows are not real-camera accuracy certifications, and the webR demo uses base R, not a verified AquaTrajectories WebAssembly package. No submitted research media is stored or uploaded.

## Website v2 independent qualification

The site build now publishes to GitHub Pages only after its **exact build artifact** completes a separate Chromium Playwright gate testing interactive controls, original-source file privacy, WCAG axe-core rules, bounded local-CSV processing, mobile layout and opt-in real webR execution. Cross-language R/JavaScript numerical parity and CVAT converter fixture checks run in an additional independent workflow. The browser can source byte-identical v0.1.1 R functions (`aqt_tracks`, `aqt_kinematics`, `aqt_group_metrics`) on demand; no whole-package WebAssembly installation is claimed. Original DIGI4ECO videos must be downloaded and processed locally under CC BY 4.0 and are never committed to the website.
