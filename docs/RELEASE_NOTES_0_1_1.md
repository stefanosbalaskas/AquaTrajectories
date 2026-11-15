# AquaTrajectories v0.1.1 — Engineering Preview

AquaTrajectories is an open-source R research package, with supporting
Python and JavaScript tools, for aquatic animal movement, fish tracking,
multiview 2D/3D reconstruction, conditional measurement uncertainty,
behavioural analysis, experiment-aligned trajectories, and scientific figures.

**This is an engineering preview, not an independently validated scientific
measurement, animal-welfare, or hardware-control product.**

## Highlights of v0.1.1

- **Research documentation portal:** complete searchable reference for all
  155 exported R functions, organized into 14 functional groups.
- **16 research articles:** reproducible workflows for video tracking,
  refractive multiview geometry, animal movement, schooling, experimental
  events, behaviour models, conditional uncertainty, benchmarks and ACI.
- **Visual science:** five-figure synthetic workbook, publication-oriented
  plotting examples, original scientific diagrams and an interactive,
  explicitly synthetic 2D/3D trajectory explorer.
- **GitHub + Zenodo citation readiness:** root `CITATION.cff` records
  Stefanos Balaskas, ORCID 0000-0003-2444-9796, MIT licensing, public
  documentation, and the exact 0.1.1 software version.
- **Safe documentation delivery:** the website source is now merged into
  `main`. The proven `gh-pages` website remains published separately,
  with Actions deployment guarded until a deliberate Pages source switch.

## Software availability

- Research website: https://stefanosbalaskas.github.io/AquaTrajectories/
- Repository: https://github.com/stefanosbalaskas/AquaTrajectories
- Reference: https://stefanosbalaskas.github.io/AquaTrajectories/reference/
- Research articles: https://stefanosbalaskas.github.io/AquaTrajectories/articles/
- Citation metadata: https://github.com/stefanosbalaskas/AquaTrajectories/blob/main/CITATION.cff

The `v0.1.0` GitHub release remains preserved as a historical engineering
preview. This new `v0.1.1` release is documentation- and citation-focused,
not a claim of new empirical accuracy evidence.

## Research limitations

- Individual fish identity and cross-camera correspondence require external,
  independently verified ground truth before biological reliability claims.
- Fisheye/water/refraction parameters and physical underwater XYZ accuracy
  require independently measured cameras and held-out surveyed references.
- Synthetic checks or software CI do not establish real fish detector
  generalization, calibrated uncertainty coverage or fish-length accuracy.
- Movement metrics and HMM states must not be interpreted as validated
  welfare, stress, preference or agency measures without dedicated evidence.
- Physical ACI actuation and welfare interlocks have not been independently
  certified for live hardware.

## Source distribution and provenance

The GitHub-generated source archives contain the public software and
documentation only. They intentionally exclude private fish videos,
nonredistributable external datasets, trained fish weights, personal
annotations, secrets, and measured physical calibration targets.

GitHub release tag: `v0.1.1` (to be created from the verified main commit).
A Zenodo DOI can be cited **only once issued** by Zenodo after ingesting
this GitHub release. DOI issuance archives and identifies the software;
it does not independently validate its scientific performance.

**License:** MIT.
