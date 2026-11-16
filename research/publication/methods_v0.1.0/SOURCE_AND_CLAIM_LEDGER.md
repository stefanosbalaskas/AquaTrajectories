# Source-to-claim audit ledger — methods-v0.1.0

**Snapshot date:** 2026-11-16. Claims are *not* certified by writing them in a paper. Recheck software source, CI artifact, original external data and statistical accuracy on the actual evaluated version.

| ID | Claim | Current source and interpretation | Status in manuscript | Evidence required before final claim |
| --- | --- | --- | --- | --- |
| C01 | Software and DOI are publicly released | GitHub `v0.1.1`, tag commit `43101800087a18d0942da4d03e21ea47099cb7a9`; Zenodo `10.5281/zenodo.24262905` | **Verified software availability** | Human check license and archived binary/source/revision equivalence |
| C02 | 155 R exports / integrated R–Python–browser interfaces | `NAMESPACE` and main `DESCRIPTION`, checked 2026-11-16; web source advanced after release | **Software architecture**, not physical accuracy | Run exported-API test against **tagged** v0.1.1; do not attribute post-tag website changes to the release |
| C03 | Original Oxford fish model inference on real pixels | `docs/OXFORD_FROZEN_SEQUENCE_BENCHMARK.md`; source original 149-frame sequence, Oxford fish model, ByteTrack | **Source-reference feasibility only** | Frozen source logs, original video/model hashes, prediction-blind reviewers and heldout multi-fish source |
| C04 | Oxford source detection F1 about 0.696 at documented operating point | `docs/OXFORD_FROZEN_SEQUENCE_BENCHMARK.md` and issue #46; source-final boxes may be model-assisted | **Historical source-agreement value, not independent validation** | Reproduce original artifact/threshold/denominator and blinded heldout review |
| C05 | Fraunhofer 101-frame model/association engineering probes exist | `docs/FRAUNHOFER_EXTERNAL_FISH_MODEL_METRICS.md`; `docs/FRAUNHOFER_REAL_MODEL_TRACKER_COMPARISON.md` | **Real-source software qualification** | Freeze exact artifacts and check possible training/annotation leakage; independently reviewed identity GT across recordings |
| C06 | Fish identity and generalized cross-domain HOTA/IDF1 independently valid | nine-gate registry `scientific_certified:false` | **Not claimed** | Whole-video heldout with independent persistent GT and official TrackEval |
| C07 | Camera videos physically synchronized | `docs/CAMERA_CLOCK_HOLDOUT.md` / `docs/REAL_FISH_TANK_LAB_CAPTURE_PROTOCOL.md` specify procedures only | **Not claimed** | Actual corresponding exposure pulses and disjoint holdout errors |
| C08 | Physically accurate underwater XYZ | `docs/PHYSICAL_LANDMARK_BENCHMARKS.md`; source 3D fish labels not metrological surveyed targets | **Not claimed** | Independently surveyed underwater 3D targets with disjoint board holdouts and units |
| C09 | Calibration of joint uncertainty / empirical coverage | `docs/ENGINEERING_FEATURE_RELEASE_GATES.md` has math/software checks | **Conditional scenarios only** | Independent measured component errors and out-of-domain interval coverage |
| C10 | Animal welfare, fish stress, ACI treatment efficacy or physical safety | `docs/EXPLORER_RESEARCH_PROTOCOL.md` ACI dry-run; registry science flags false | **Not claimed** | Approved live trials, blinded biological labels, physical stop tests, independent randomized tanks |
| C11 | Official scientific release passes | `inst/evidence/scientific-validation-gates.json`: `scientific_release_approved:false` and all 9 `scientific_certified:false` | **Explicitly blocked** | External audited evidence in each relevant gate, not self-editing flags |
| C12 | Paper is preregistered | No registration ID or receipt has been supplied | **Not registered** | A real registration platform return value with timestamp |
| C13 | Methods paper accepted / manuscript externally peer reviewed | No manuscript submission decision | **Not submitted** | Editor decision, review files, editorial correspondence |

## Evidence hierarchy

1. **Source software contract:** versioned code, software tests and CI log.
2. **Original-source benchmarking:** real video, sometimes source-final annotations that may be model-assisted.
3. **Independent biological/physical truth:** prediction-blind, separately surveyed, heldout reference and reviewed provenance.
4. **Scientific inference:** independent replicates, prespecified outcomes, uncertainty, ethics and interpretation.

A level-1 or level-2 demonstration cannot be promoted to level-3/level-4 by changing prose or an approval field. A third-party source paper result is not an AquaTrajectories finding.

## Source URLs and exact file pointers

- Release: https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.1
- Archival DOI: https://doi.org/10.5281/zenodo.24262905
- Structural scientific state: https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/inst/evidence/scientific-validation-gates.json
- Umbrella issue #51: https://github.com/stefanosbalaskas/AquaTrajectories/issues/51
- External benchmark issue #46: https://github.com/stefanosbalaskas/AquaTrajectories/issues/46
- Real-data lab intake: https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/docs/REAL_FISH_TANK_LAB_CAPTURE_PROTOCOL.md
- Official tracking: https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/docs/OFFICIAL_FISH_HOTA_IDF1_PROTOCOL.md

**Source mismatch safeguard:** v0.1.1 tagged source and later main/docs do not have to be identical. Each empirical run records the actual commit and software environment; do not rewrite version history or quietly replace the preregistered baseline.

