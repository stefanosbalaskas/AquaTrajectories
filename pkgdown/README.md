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

GitHub Actions builds a preview on PRs, and deploys from `main` only after GitHub Pages is configured to use **GitHub Actions** as its publishing source. Review the preview artifact and scientific limitation language before merging.

Neither the website nor any generated figure is evidence of independently certified biological measurement, underwater calibration, or ACI hardware safety.

## Website-only research improvements

Do not change the CRAN candidate or existing GitHub release to publish website content. The homepage shows the current *published* GitHub version, v0.1.1. The CRAN candidate 0.1.2 is not advertised as released. The new pages are: five-minute onboarding, capability matrix, video-to-results workflow, tank experiment starter kit, identity/occlusion explanation, and evidence dashboard. All illustrative files are synthetic, metadata examples, or empty schemas. Maintain source Rmd and pkgdown/index.md as the authority; never hand-edit generated HTML on gh-pages.
