# Scientific validation status and research limitations

## Scientific status of the published v0.1.1 release

**AquaTrajectories v0.1.1 is a published, citable software release, not
an independently certified fish-welfare or underwater physical metrology
system.**

The release includes tested R/Python/JavaScript contracts, synthetic
integration tests, and a fail-closed scientific gate. Those are stronger
than untested proof-of-concept scripts but are **not** substitutes for
independent measurement validation.

![A conceptual progression from engineering checks to independent
scientific certification.](../validation.svg)

The last four stages are outstanding evidence requirements, not asserted
passes.

### What the engineering release establishes

- A documented public R API containing **155 exported functions**.
- Native R software components for video outputs, trajectories, optics,
  movement, statistical utilities and figures.
- Python video integration contracts and local JavaScript exploratory
  interfaces.
- Tested conditional simulation and uncertainty scenarios with explicit
  assumptions.
- Whole-package release qualification, including source, tests and
  synthetic integration evidence.

**Release citation:** [v0.1.1 on
GitHub](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.1)
· [Zenodo DOI:
10.5281/zenodo.24262905](https://doi.org/10.5281/zenodo.24262905). CRAN
candidate 0.1.2 is a separate package-source qualification track, not
the published version of this site.

**Historical evidence:** v0.1.0 was tagged at commit
`f63885411d55df764e452846758756114b90423a`. The original v0.1.0
qualification protocols below remain accessible as historical source
records; they must not be mistaken for a new independent validation of
v0.1.1.

See the [current capability
matrix](https://stefanosbalaskas.github.io/AquaTrajectories/articles/capabilities-and-validation.md)
and [source-linked evidence
dashboard](https://stefanosbalaskas.github.io/AquaTrajectories/articles/research-evidence-dashboard.md)
for a function-by-function and claim-by-claim orientation.

### Outstanding empirical gates

1.  **Biological identity:** externally reviewed long-term multi-fish
    identity labels; occlusion and cross-view ID switches.
2.  **Detection:** independent model and dataset holdout with species,
    shadow, density and recording variations.
3.  **Physical XYZ:** independently surveyed reference targets in water,
    correct glass/lens parameters, depth and length accuracy.
4.  **Clock accuracy:** independently recorded physical synchronization
    markers and heldout exposure evidence.
5.  **Joint uncertainty:** observed pixel/ID/calibration distributions
    and independent real holdout interval coverage.
6.  **Behavioural interpretation:** validated biological reference
    labels rather than speculative HMM state names.
7.  **Experimental inference:** appropriate randomization and
    independent tank-level replication.
8.  **Real ACI:** ethical approval, operator procedures, measured
    actuator latency and physical hard stops.
9.  **External replication:** independent scientific testing, permission
    to use external benchmarks, and peer-reviewed evidence.

### How to describe findings accurately

| Supported wording | Wording that would overclaim |
|----|----|
| “A 2D/3D trajectory software pipeline was executed.” | “All fish were correctly identified.” |
| “The reconstruction produced XYZ given external calibration.” | “Underwater accuracy was validated.” |
| “The HMM assigned probabilistic latent states.” | “Fish stress was detected.” |
| “Conditional measurement scenarios changed outputs.” | “The stated intervals have measured 95% coverage.” |
| “Software tests passed.” | “The complete biological system is validated.” |
| “A simulator exercised ACI control contracts.” | “The physical animal device is safe.” |

### Historical v0.1.0 qualification sources (not current release links)

- [source
  protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.0/docs/SCIENTIFIC_RELEASE_READINESS.md)
- [source
  protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.0/docs/ENGINEERING_FEATURE_RELEASE_GATES.md)
- [source
  protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.0/docs/RELEASE_CANDIDATE_0_1_0.md)

See the [current v0.1.1
release](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.1)
and the [historical v0.1.0 source methods
library](https://github.com/stefanosbalaskas/AquaTrajectories/tree/v0.1.0/docs).

The release is open-source research software. It is not a medical,
animal-welfare diagnostic or independently safety-certified controller.
