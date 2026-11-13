# Wave 14I — real original Fraunhofer Datumaro A/B and fish YOLO training source audit

Before training a second fish-specific detector or claiming new
species/domain-generalizable accuracy, establish exactly what the
original source **training** and **heldout** packages actually contain.
The original [Fraunhofer HHI FishTracking source page](https://cvg.hhi.fraunhofer.de/FishTracking.htm)
links these three ZIP files:

- `https://cvg.hhi.fraunhofer.de/FishTrackingData/video_a/datumaro_a.zip`
- `https://cvg.hhi.fraunhofer.de/FishTrackingData/video_b/datumaro_b.zip`
- `https://cvg.hhi.fraunhofer.de/FishTrackingData/training_yolo_ultralytics.zip`

The original page explicitly says Datumaro is the recommended format
for combining segmentation, 2D boxes **and persistent fish track IDs**;
MOT supplies tracker-evaluation coordinates but lacks rich segmentation
attributes. Wave14C independently audited the raw MOT ZIPs: A has
**260 distinct GT IDs**, despite 256 in the source webpage's profile;
B has **45 GT IDs**. We must audit original Datumaro fields before
trying to reconcile those counts, and must not simply rewrite true IDs
or silently prefer whichever count seems plausible.

## What the source-data auditor actually verifies

The standalone standard-library script
`inst/python/aqt_fraunhofer_train_split_audit.py`:

1. Downloads *exact source-page URL* archives with their original
   publication paths (all original source URLs preserved in output).
2. Enforces ZIP path traversal, member-size, inflation and member-count
   safeguards; no untrusted Python/YAML source is executed.
3. Hashes **every original image file** in each ZIP (SHA256 of actual
   image bytes, not only filenames), plus source ZIP digests and
   canonical per-image manifest digests. It does not redistribute
   the original training or evaluation images.
4. Reports exact pixel-byte duplicate image counts within each
   archive, and **training-versus-evaluation source image SHA
   intersection counts for both A and B**. When identical raw images
   are present in training and evaluation, the CI must fail. That
   would be real evidence of a train/evaluation file leakage risk.
5. Inspects Datumaro annotation JSON container structure, number
   of items, annotation-type counts, and observed persistent-ID
   attributes wherever recognizable; it does not assume every
   annotation is an independent human-reviewed track.
6. Explicitly declines to certify independence of aquarium,
   camera environment, fish cohorts, temporal near-duplicates,
   annotation construction or verified source TLS peer identity.
   The HHI host's certificate issuer chain currently fails the
   GitHub Actions Linux trust store, requiring source-inspection-only
   `curl --insecure` and clearly marked provenance limitation.

A zero *exact byte* image overlap is a **necessary but insufficient**
prerequisite for independent heldout evaluation; resized/cropped/nearby
frames, same tank, same fish and training on model-assisted labels
still require separate expert adjudication.

## Next: frozen alternative fish detector

Only after this real source split is audited:
- freeze a fish-specific YOLO model architecture and original
  initialization checkpoint with SHA256 and pinned training library;
- train exclusively on the source training files, **never on either
  A or B eval annotations**; preserve fixed seed, epochs and
  frozen model-preprocessing settings;
- output actual fish detections on all 101 A and 101 B original pixels,
  not source ground-truth boxes;
- compare YOLO and independent Oxford EfficientDet transfer using
  predefined score/IoU thresholds, AP and failure strata, and
  ByteTrack + a second independent tracking algorithm;
- score HOTA/DetA/AssA/IDF1/IDSW by full recording, report video-level
  variability and annotation uncertainty without treating fish frames
  as independent tanks;
- do not describe the resulting performance as externally
  prediction-blind independently certified unless a third party
  audits video/cohort source separation and reference track IDs.

Independent physical underwater XYZ, synchronized exposure pulses,
joint uncertainty coverage, ethological welfare labels, and actual
ACI hardware intervention experiments remain separate uncompleted
scientific acceptance gates in issue #51.

See [priority 1–2 tracking gate #46](https://github.com/stefanosbalaskas/AquaTrajectories/issues/46)
and [all nine research gates #51](https://github.com/stefanosbalaskas/AquaTrajectories/issues/51).
