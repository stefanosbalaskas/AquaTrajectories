# Wave 14F — source-verified 13-camera underwater physical target measurement evidence

This milestone integrates an actual **independent external research
source** documenting physical target-length accuracy in a real
underwater multi-camera aquarium, from the MIT-licensed
[AquaCal](https://github.com/McGrathLab/AquaCal) work
by Lancaster (2026). It is a **source-evidence audit**, not an
AquaTrajectories reconstruction accuracy experiment.

Exact original public repository commit:
`1ed009687ffe9d5e82f0ee8a613bc1355d455ecd`.

Two immutable Git source blobs are downloaded from that specific commit,
then independently hashed using Git's blob algorithm:
- `experiments/results/real_rig_metrics.json`:
  `645ce20043966394dec779052a8ef27fb31697b1`.
- `experiments/results/benchmark.json`:
  `bc98aad6ea59320e54e9cc451a9e2f8be58092e3`.

## Actual real-rig reported physical experiment

- 13 cameras at a real production calibration rig.
- 52 source holdout frames reported in the original benchmark object.
- **7,762 physical ChArUco inter-corner length comparisons**.
- Known **60 mm target spacing**.
- Original source MAE **0.258177 mm** and RMSE **0.628139 mm**
  for the external project's validated inter-corner geometry.
- Source mean relative absolute length error **0.430295%**.
- Original source pooled pixel reprojection RMS **0.927661 px**;
  mean per-primary-camera reprojection metric **0.824039 px**.

The source numerical consistency check recomputes
`RMSE = 1000 * sqrt(source_error_mean_m^2 + source_error_std_m^2)`
and `relative_MAE = MAE_mm / 60mm * 100`.
It verifies agreement between two **separate source evidence files**,
the original source commit and Git blob hashes, fixed ChArUco
OpenCV 4.13.0 and source rig/holdout scope.

## Important scientific limitations

These values characterize **AquaCal**, not AquaTrajectories.
The original individual physical 3D target coordinates, video
frames, independently surveyed rig geometry, source author
labeling details, and exposure markers are not included in this
small-source-check milestone. The source references companion
Zenodo Record A (large original frames, DOI
https://doi.org/10.5281/zenodo.22116461) and Record B
(reference outputs and run metadata) for end-to-end replication.
The original upstream source reports OpenCV 4.13.0 can change
which ChArUco corners are detected, so all comparisons need
frozen detection settings and explicitly heldout physical
targets; published source results cannot be indiscriminately
transferred to our refractive model.

**AquaTrajectories own physically surveyed XYZ reconstruction
accuracy is NOT computed.** The source summary only supplies an
externally published reference and a validated interface to later
physical benchmark fixtures. Do not close priority 4 on the
source result alone. To close it, run the actual AquaTrajectories
refraction/triangulation stack on independent 2D observations
and heldout real surveyed XYZ targets with a traceable calibration
fit and separate test boards. Also measure joint uncertainty
interval coverage on external real targets.

Priority 3 true synchronized exposure pulses and animal/fish
tracking, HOTA and fish welfare evidence are independent.
Follow issues #46 and #51.
