# AquaTrajectories documentation portal

This directory holds **website source**. The project's existing scientific protocol files under `docs/` are never used as generated output.

- `pkgdown/index.md`: independent landing page (preserves GitHub README).
- `_pkgdown.yml`: Bootstrap 5 theme, all 155 exported R functions in 14 curated categories, article routing.
- `pkgdown/extra.css`: accessible navy/teal brand.
- `pkgdown/assets/*.svg`: original illustrations; conceptual, not observations.
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
