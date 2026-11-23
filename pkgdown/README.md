# AquaTrajectories documentation portal

This directory holds **website source**. The project's existing scientific protocol files under `docs/` are never used as generated output.

- `pkgdown/index.md`: independent landing page (preserves GitHub README).
- `_pkgdown.yml`: Bootstrap 5 theme, all currently exported R functions in curated categories (188 functions, 15 families on this feature branch), article routing.
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

Website source updates must not overwrite immutable version tags or imply CRAN publication. The homepage shows the currently published **v0.2.1 GitHub software release**; the v0.1.1 Zenodo DOI is historical and version-specific. The early website pages were: five-minute onboarding, capability matrix, video-to-results workflow, tank experiment starter kit, identity/occlusion explanation, and evidence dashboard. All illustrative files are synthetic, metadata examples, or empty schemas. Maintain source Rmd and pkgdown/index.md as the authority; never hand-edit generated HTML on gh-pages.

## Phase 1 usability

Main-branch website source adds visible lab/experiment routes, 22 direct plot-to-code/function help/version-pinned implementation links, accessible deep-link expansion and keyboard focus styles, and a source-only metadata normalizer after pkgdown builds. Review the PR preview artifact; the official historical v0.1.1 software release is unchanged.

## Phase 2 scientific teaching (website only)

Four static browser labs provide deterministic **synthetic** object detection/track-ID didactics, vector/school/clock mathematics, three adjustable SVG plotting previews plus version-pinned R code recipes, and downloadable planned experiment protocols/blank CSV manifests. The website does not claim official HOTA/IDF1, independent video performance, live animal welfare or physical XYZ calibration. Source files are in `pkgdown/assets`, connected from the home page and the new `vignettes/articles/scientific-teaching.Rmd`. Node teaching-core regression tests run in the pkgdown CI build before smoke testing.

## Phase 3 research laboratory (website only)

New `research-*.html` modules in pkgdown assets demonstrate single-interface above-water refracted rays, opt-in pinned webR v0.6.1 with GitHub Pages PostMessage worker, source-frame-matched local multiview video + XYZ inspection, and CSV-only on-device QC. The linked `research-laboratory.Rmd` discloses scientific boundaries. Pure numerical and CSV validation functions have deterministic Node regression tests. Browser workflows are not real-camera accuracy certifications, and the webR demo uses base R, not a verified AquaTrajectories WebAssembly package. No submitted research media is stored or uploaded.

## Website v2 independent qualification

The site build now publishes to GitHub Pages only after its **exact build artifact** completes a separate Chromium Playwright gate testing interactive controls, original-source file privacy, WCAG axe-core rules, bounded local-CSV processing, mobile layout and opt-in real webR execution. Cross-language R/JavaScript numerical parity and CVAT converter fixture checks run in an additional independent workflow. The browser can source byte-identical v0.1.1 R functions (`aqt_tracks`, `aqt_kinematics`, `aqt_group_metrics`) on demand; no whole-package WebAssembly installation is claimed. Original DIGI4ECO videos must be downloaded and processed locally under CC BY 4.0 and are never committed to the website.


## Scientific Core 2.0 documentation refresh

The site now explains the v0.2.1 engineering release and its 188-function API, actual 100.0000% instrumented expression coverage, cross-platform workload measurements and independent locked 17-row trajectory-to-report proof. The historical browser-parity v0.1.1 native-R source files and historical DOI remain deliberately pinned; they do not claim to be v0.1.2 native source. The new release guide is tested in site CI before gh-pages publication.
