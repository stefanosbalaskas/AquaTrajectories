# AquaTrajectories: published GitHub and Zenodo software archive

## Published and citable (2026-11-15)

- **Official GitHub release:** [AquaTrajectories v0.1.1](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.1)
- **Zenodo version DOI:** [10.5281/zenodo.24262905](https://doi.org/10.5281/zenodo.24262905)
- **Research website:** https://stefanosbalaskas.github.io/AquaTrajectories/
- **Software author:** Stefanos Balaskas (ORCID: https://orcid.org/0000-0003-2444-9796)
- **License:** MIT
- **Publication status:** normal GitHub software release (not a pre-release).
- **CRAN:** preparing submission; not yet accepted or listed. Do not use `install.packages("aquaTrajectories")` until CRAN publishes it.

The DOI is version-specific and identifies the published 0.1.1 software record.
It does not constitute independent scientific accuracy certification.
Original videos, private annotations, detector weights and physical underwater
targets are not archived as part of this public source release.

## Citing the version

Balaskas, S. (2026). *AquaTrajectories: Aquatic Animal Movement and
Multiview Trajectories* (Version 0.1.1) [Computer software]. Zenodo.
https://doi.org/10.5281/zenodo.24262905

Machine-readable source citation: [CITATION.cff](../CITATION.cff).

## Future releases

For the next version, update the `DESCRIPTION` and `CITATION.cff` version,
complete exact-source qualification, then tag a new GitHub release. Confirm the
Zenodo GitHub integration is enabled, let Zenodo ingest that new tag, and
replace that version's DOI with the DOI actually issued. Do not retag
the historical v0.1.1 release or modify the already published Zenodo archive.

## Documentation website deployment

GitHub Pages currently deploys static `gh-pages`/(root). The repository's
pkgdown workflow builds the site from source while its Actions deployment
remains opt-in. Keep the source website (`pkgdown/` + `vignettes/articles/`)
and the live site in sync. The source can be published automatically later
after changing the GitHub Pages publishing source in repository Settings
and opting in with `AQT_PAGES_ACTIONS_ENABLED=true`.
