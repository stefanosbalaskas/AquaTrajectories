# Validation methods and independent benchmarks

## Scientific validation

AquaTrajectories provides the **machinery for testing predictions**, but
test code alone is not evidence that a detector, tracker, measurement
device or biological interpretation is accurate.

![Validation stages spanning engineering tests, annotations, metrology,
tank replication and external audit.](../validation.svg)

The steps depict evidence requirements, not certification status.

### Detection measures

When matching declared detector boxes against independently reviewed
reference boxes, common metrics are:

``` math
\mathrm{Precision}=\frac{TP}{TP+FP},\quad
\mathrm{Recall}=\frac{TP}{TP+FN},\quad
F_1=\frac{2PR}{P+R}.
```

Intersection-over-Union is measured on matched boxes. AP/mAP summarize
precision across confidence-ranked predictions under a **specified** IoU
and class protocol.

Entry points:
[`aqt_box_iou()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_box_iou.md),
[`aqt_detection_match()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_match.md),
[`aqt_detection_metrics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_metrics.md),
[`aqt_detection_ap()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_ap.md),
[`aqt_detection_map()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_detection_map.md).

Native AP implementations should not be described as a complete COCO
benchmark without matching official semantics.

### Tracking measures

Tracking evaluation additionally requires temporal identity reference
labels.
[`aqt_tracking_match()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tracking_match.md)
and
[`aqt_tracking_metrics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_tracking_metrics.md)
provide identity-based diagnostics;
[`aqt_video_bundle_benchmark()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_video_bundle_benchmark.md)
reports compatible frame and scope denominators.

The official HOTA/TrackEval protocols and the native R tracking
summaries are **not interchangeable**. Track IDs inherited from detector
output do not constitute independent reference identities.

### Physical stereo target evaluation

A real underwater benchmark needs surveyed physical coordinates,
consistent units, independent calibration trials, and disjoint target
assemblies for fitting versus holdout. Analyze reconstructed error and
failure rates by depth, not only averages.

[`aqt_stereo_landmark_benchmark()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_stereo_landmark_benchmark.md)
and
[`aqt_target_holdout_benchmark()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_target_holdout_benchmark.md)
report 3D errors for supplied physical targets.

### Beware of leakage

- Distinct frames from one video are not necessarily independent test
  samples.
- Annotations corrected while viewing predictions may create
  model-assisted reference agreement.
- Calibration and test targets must not overlap.
- Source-only results on a published clip do not imply species- or
  site-wide generalization.
- Synthetic tests detect engineering errors but cannot validate live
  welfare outcomes.

### Current scientific release qualification

The software release contains an explicitly *fail-closed* scientific
gate. Do not claim that independent fish identity, physical underwater
metrology, real device safety or welfare effects have passed that gate.

**Protocols:** [source
protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.0/docs/VALIDATION_CONTRACT.md),
[source
protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.0/docs/OFFICIAL_FISH_HOTA_IDF1_PROTOCOL.md),
[source
protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.0/docs/SCIENTIFIC_RELEASE_READINESS.md).

For status language suitable for citing the package, use the [scientific
status
page](https://stefanosbalaskas.github.io/AquaTrajectories/articles/scientific-status.md).
