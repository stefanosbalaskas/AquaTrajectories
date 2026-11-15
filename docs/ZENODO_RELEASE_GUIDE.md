# AquaTrajectories Zenodo archival and DOI guide

## Status and scope

- `v0.1.0` is already an existing GitHub release and must not be deleted,
  republished or retagged to force Zenodo ingestion.
- `v0.1.1` is a **documentation and citation update**, not scientific
  accuracy certification or a new independent biological validation.
- Repository source: https://github.com/stefanosbalaskas/AquaTrajectories
- Public research website: https://stefanosbalaskas.github.io/AquaTrajectories/
- GitHub release page: https://github.com/stefanosbalaskas/AquaTrajectories/releases
- Zenodo GitHub connection: https://zenodo.org/account/settings/github/

## Publish a new software version (owner action)

1. In Zenodo's connected GitHub repository list, make sure the
   `stefanosbalaskas/AquaTrajectories` toggle is **enabled**.
2. Wait for all mandatory GitHub Actions checks on the release commit to pass.
3. Open GitHub **Releases > Draft a new release**.
4. Create **new tag `v0.1.1`** targeting the exact current `main` head.
   Do not reuse `v0.1.0` or create the tag on `gh-pages`.
5. Use the release title **AquaTrajectories v0.1.1 — Engineering Preview**.
6. Use NEWS.md for a concise release description; explain that the update
   adds the pkgdown documentation portal and citation metadata and does not
   certify real-data tracking, underwater accuracy, welfare or device safety.
7. For the first Zenodo archive, prefer a normal GitHub release clearly
   labeled **Engineering Preview**, rather than relying on prerelease
   processing. This does not claim production readiness or scientific accuracy.
8. Publish the release. Source-code .zip/.tar.gz archives are provided
   automatically by GitHub. Do not attach private data, recorded fish videos,
   externally licensed datasets, credentials, or model weights.
9. Open Zenodo's GitHub integration page and find the newly ingested release.
   Zenodo processing may take time. If ingestion fails, check toggle and errors.
10. Open the resulting Zenodo **record DOI**, verify that type is Software,
    version is 0.1.1, creator is Stefanos Balaskas and license is MIT, and
    confirm the source archive corresponds to GitHub `v0.1.1`.
    Record the exact DOI; do not fabricate or predeclare a number.
11. After Zenodo issues the DOI, add a DOI badge and citation link to the
    repository README and update the citation metadata accordingly.

## Citation metadata

Root `CITATION.cff` is authoritative for this version. Zenodo supports
this file when a conflicting `.zenodo.json` is not present.
It intentionally omits an unissued DOI and speculative release date.
Author ORCID: https://orcid.org/0000-0003-2444-9796

## Existing website publishing source

GitHub Pages currently publishes static files from `gh-pages`/(root).
The science portal's Actions deployment job is opt-in. To migrate safely,
first confirm the workflow build passes, then change repository
**Settings > Pages > Build and deployment > Source** to
**GitHub Actions** and add repository Actions variable
`AQT_PAGES_ACTIONS_ENABLED=true`. Only then allow the workflow to deploy
built `site/` artifacts. Keep the existing `gh-pages` branch as a
rollback snapshot; never overwrite scientific source `docs/`.
