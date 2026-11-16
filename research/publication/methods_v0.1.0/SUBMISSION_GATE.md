# Before journal submission — independent scientific review gate

**Current state: BLOCKED.** Publishing an accessible software package or receiving CRAN acceptance will not clear this methods-paper empirical review gate.

## Required before declaring the manuscript an empirical validation study

- [ ] Verify final author order, institutional affiliations, CRediT roles, conflict-of-interest statement, funding, software rights and permission from all contributors.
- [ ] Verify the exact version of AquaTrajectories used in every evaluation. Record release tag and commit; retain the version-specific software DOI.
- [ ] Confirm journal type and original methodological contribution. Do not describe an integration of existing algorithms as a newly invented detector/association theory. State actual architectural novelty and supporting comparison.
- [ ] Obtain approved dataset licenses and independent original recordings/annotated fish identities; preserve source archive SHA256, intended complete evaluated frames, all reviewed empty frames, and prediction-blind annotation audit.
- [ ] Audit model training/test overlap, freeze detector checkpoint and inference settings before testing.
- [ ] Run official pinned HOTA/IDF1/DetA/AssA and explicit tracking baselines on heldout recordings, reporting unit-level results and uncertainty.
- [ ] Verify physical camera synchronization using real independent exposure/marker records with fit/holdout timing.
- [ ] Obtain surveyed underwater XYZ target assemblies independent of camera calibration; report absolute error, invalid fraction, biases and error-versus-depth.
- [ ] Validate joint uncertainty intervals against real independent residuals, not invented random draws.
- [ ] Obtain verified ethics approval and **multiple independent randomized tanks** before any causal fish-welfare/ACI interpretation. If no live animal study, remove these biological effect claims.
- [ ] Complete heldout power/precision planning, independent trial allocation, study-specific numerical tolerances and genuine preregistration **before** the confirmatory test.
- [ ] Populate result tables only from archived original data and versioned computation; compare code/dataset licenses.
- [ ] Check against ARRIVE 2.0 for animal experiments where applicable.
- [ ] Confirm every citation from DOI/source, revise AI-assistance disclosure and author oversight, and verify figures are based on the specified inputs.
- [ ] Run `scripts/verify.py --mode evidence`; keep **BLOCKED** until independent records and signatures/approvals can be externally checked.
- [ ] Freeze an archival version of the *actual final manuscript and reproducibility package* with new checksum and DOI where appropriate.

## Possible publication paths (fit is conditional, no acceptance claim)

1. **Full methods/software paper** (current manuscript) for a venue accepting computational method frameworks plus substantive external validation. Follow target journal's requirements; **Methods in Ecology and Evolution** standard new computational methods normally expect simulations or benchmark data and methodological novelty beyond connecting existing tools.
2. **Software application / software note** describing a released usable implementation; avoid overstated empirical performance. **Ecology and Evolution** explicitly considers software notes and does not regard a pre-existing CRAN release as automatically prohibitive.
3. **Short software paper** (optional separate future draft). **JOSS** currently screens for substantial public development history and actual research use; do **not** assume a new November 2026 project meets its six-month public history requirement.

## Current blocker summary

`external_fish_identity=false`; `physical_exposure=false`; `surveyed_xyz=false`; `calibrated_uncertainty=false`; `randomized_tank_effect=false`; `live_aci_safety=false`; `independent_scientific_release=false` in the project's public scientific gate framework. Our package intentionally does not replace those claims with guesses.

**CRAN PR #79** must remain separate from this paper/protocol branch. Do not edit or reissue the exact 0.1.2 source tarball for manuscript changes.
