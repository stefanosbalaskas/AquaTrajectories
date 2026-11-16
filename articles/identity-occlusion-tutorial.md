# Fish detection, tracking and identity: visual occlusion tutorial

## A visible track number is not a fish identity certificate

The [interactive synthetic
explorer](https://stefanosbalaskas.github.io/AquaTrajectories/synthetic-explorer.md)
includes optional **occlusion** and **ID-switch** demonstrations. These
are deliberately simple, deterministic animations of five invented
paths. They illustrate the distinction between a visible label and a
permanent biological fish identity; they do **not** emulate a validated
detector or a statistical distribution of fish behavior.

### Four different questions

| Question | Typical output | What it does not establish |
|----|----|----|
| Is an animal visible? | A detector box, confidence, species hypothesis | That the box is correct without ground truth |
| Where is it across adjacent frames? | Camera-local track ID | Permanent animal identity |
| Does the same fish reappear after occlusion? | A proposed identity match, with uncertainty | Identity truth without independent review |
| Is it the same fish in another camera? | Calibrated correspondence hypothesis | Reliable fish re-identification without evidence |

### Try the interactive illustration

1.  Open the [synthetic
    explorer](https://stefanosbalaskas.github.io/AquaTrajectories/synthetic-explorer.md).
2.  Enable **Simulated occlusion** and move the slider around frames
    90–125. One synthetic track temporarily disappears from observation.
    Its underlying invented path still exists, but observed positions
    are missing.
3.  Enable **Illustrative ID switch**, advance past frame 125 and
    inspect the labels for the first two display tracks. They can
    exchange *observed labels* without the underlying invented fish
    exchanging bodies.
4.  Compare top (XY), side (XZ), front (YZ) and isometric projections. A
    drawing of 3D geometry is not measured physical XYZ.
5.  Switch the learning toggles off to see the unchanged deterministic
    trajectories.

The rendered label changes are pedagogical only; no tracker actually
ran. The figure explicitly marks simulated missingness. The example must
never be included as measured biological performance.

### Auditing real research predictions

Compare predictions with **independently adjudicated** camera/frame
truth. Report evaluated frames with and without detections; identity
switches on occlusions; explicit coverage, accuracy and association
metrics where scientifically defined. Group performance by density,
shadows, species, camera view and track fragmentation. Report holdout
provenance.

See [video
intake](https://stefanosbalaskas.github.io/AquaTrajectories/articles/video-tracking.md),
[research
datasets](https://stefanosbalaskas.github.io/AquaTrajectories/articles/research-datasets.md),
[the evaluation
contract](https://stefanosbalaskas.github.io/AquaTrajectories/articles/validation-and-benchmarks.md),
and [the capabilities
matrix](https://stefanosbalaskas.github.io/AquaTrajectories/articles/capabilities-and-validation.md).
