# Capability and scientific validation matrix

## What the package can and cannot establish

The official [v0.1.1 GitHub
release](https://github.com/stefanosbalaskas/AquaTrajectories/releases/tag/v0.1.1)
is **published and citable**. It is not an independently certified fish
observation, welfare, metrology or device-control system. A software
function existing and passing tests is **not** evidence that its
biological prediction is accurate.

The table below summarizes software capabilities and
independent-evidence requirements, based on the repository’s [scientific
validation gate
registry](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/inst/evidence/scientific-validation-gates.json)
(development evidence dated 2026-11-12). This is a **source-linked
research-readiness matrix**, not a live certification service.

| Capability | Implemented software / demonstration | Must be supplied externally | Independent scientific claim |
|----|----|----|----|
| Fish detections | Optional video runner and box metrics; public dataset probes | Fish-trained detector weights; held-out reviewed annotations | **Not certified** across tanks/species |
| Within-camera tracks | Imports, camera-local track representation, identity metrics | Adjudicated fish IDs; occlusion/density evaluation | **Not certified** as permanent identities |
| Multiview identity | Geometric association and reviewer/abstention contracts | Clock evidence, calibrated cameras and verified cross-view matches | **Not independently verified** |
| Exposure timing | PTS-aware adapters, sync offset/drift estimators | Real simultaneous timing markers and held-out drift | **Not physically certified** |
| Underwater XYZ | Camera models, refraction-aware reconstruction, quality diagnostics | Physical lens/window/water calibration and surveyed XYZ targets | **Not independently certified** |
| Kinematics, schooling | Path, speed, geometry and spatial summaries | Valid physical units, trajectories and fish identities | **Descriptive outputs, conditional on inputs** |
| Experimental events | Time alignment, replicated-tank analysis utilities | Original event logs, allocation and independent tanks | **Not causality without design** |
| HMMs and functional models | Conditional decoding, changepoints and longitudinal analysis | Valid model assumptions and ethological reference labels | **Not a stress or welfare diagnosis** |
| Uncertainty scenarios | Perturbation and sensitivity workflow contracts | Measured detector, ID, timing and optics errors; holdout coverage | **Not empirically calibrated coverage** |
| Browser explorer | Interactive deterministic synthetic trajectories | Real videos, camera models and independent annotations | **Teaching visualization only** |
| Physical ACI | Fail-closed integration and simulation contracts | Ethics approval, independent interlocks and validated apparatus | **Not a safety-certified controller** |

### Evidence levels

1.  **Implemented:** callable public software/API exists.
2.  **Software-qualified:** tested source, contracts, examples and
    workflows.
3.  **Real-source assessed:** real data formats or controlled benchmark
    procedures exercised; this does not imply performance is certified.
4.  **Independently validated:** external held-out biological and
    physical reference evidence supports a specified claim. **Not
    asserted for the system as a whole.**

Read the [full evidence
dashboard](https://stefanosbalaskas.github.io/AquaTrajectories/articles/research-evidence-dashboard.md)
for links to the real source contracts and checks. The [scientific
status
statement](https://stefanosbalaskas.github.io/AquaTrajectories/articles/scientific-status.md)
provides detailed wording guidance.

### Input-specific limitations

A 2D fish track is a sequence of image- or tank-plane positions, not a
biological identity guarantee. Two GoPro videos do not automatically
yield physical 3D; independent calibration, actual synchronization and
consistent correspondences are required. A small reprojection residual
measures internal fit, not underwater target accuracy.

### Which guide should I use?

- Have only CSV coordinates? [Five-minute quick
  start](https://stefanosbalaskas.github.io/AquaTrajectories/articles/quickstart-five-minutes.md)
  and [movement and
  schooling](https://stefanosbalaskas.github.io/AquaTrajectories/articles/movement-and-schooling.md)
- Have original fish footage and a detector? [Video-to-results
  guide](https://stefanosbalaskas.github.io/AquaTrajectories/articles/video-to-results.md)
- Have synchronized stereo recordings? [Multiview geometry and
  refraction](https://stefanosbalaskas.github.io/AquaTrajectories/articles/multiview-3d.md)
- Planning repeated experimental recordings? [Experiment starter
  kit](https://stefanosbalaskas.github.io/AquaTrajectories/articles/experiment-starter-kit.md)
- Confused by tracker IDs and occlusions? [Visual identity
  tutorial](https://stefanosbalaskas.github.io/AquaTrajectories/articles/identity-occlusion-tutorial.md)
