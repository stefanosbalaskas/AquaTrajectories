# Milestone 05 — genuine Oxford fish-video analysis and publication

## Purpose and study scope

This is a REAL (not simulated) aquarium data demonstration of the **existing**
external Python computer-vision -> AquaTrajectories R research pipeline.
Source: the Oxford Visual Geometry Group Detect+Track Picasso triggerfish
dataset, 15-video evaluation archive.

Official source and paper: https://www.robots.ox.ac.uk/~vgg/research/fish/

Original zip: https://thor.robots.ox.ac.uk/~vgg/data/fish/fish-tank-obstacles-eval-15.zip
Original archive SHA-256:
91c71d297b7bfa6bd19c6f34ec5d12e1534bf7ef2f90d3249662605507ca9ae4

Original clip member: eval/F30_T15.mp4 (149 frames, 1920 by 1080 pixels)
Original MP4 SHA-256:
acd118909b7bd44b013450e35525409ab2bfe53e15e81f48834fe33bfea682c0

This specific recording **was previously evaluated in development**. This
milestone therefore demonstrates integration on a genuine original recording,
but DOES NOT qualify an untouched, session-independent generalization test.

Original historical authentic model run: GitHub Actions 43287906771,
artifact wave13e-real-model-detections-tracks-and-source-agreement.
That earlier real execution used Oxford's frozen EfficientDet-D2 v2 fish
detector, followed by a real ByteTrack implementation. This is **not YOLO**,
and the Milestone 05 handoff does **not claim to perform new model inference**.
The original model/tracker source files and their checksums are independently
read from the persisted historical source run before the R handoff. The
original MP4 archive is separately re-downloaded and SHA-256 verified;
FFprobe rechecks all 149 real source timestamps and image dimensions.

## Original biological study restrictions

Oxford reports individual Picasso triggerfish traversing an obstacle
environment in a video trial. The source experiment followed five fish
over multiple trials, NOT five simultaneous fish in this exact video.

Accordingly:
- Individual-fish movement, pixels/s, path length, review coverage and
  source-image trajectory figures are the permitted scientific descriptions.
- **No schooling profile is run for this one-fish trial**. Multiple predicted
  tracker IDs may be fragments of one fish, not a real fish school.
- No independent body identity GT or reliable cross-camera biological ID
  certification is present, so path lengths are *tracker-ID-local* conditional
  measurements; they are not guaranteed continuous whole-fish paths.
- Original source-reviewed box annotations may have been seeded with model
  proposals. Their reported IoU/precision/recall/F1 quantify agreement with
  source review, not fully prediction-blind external detector accuracy.
- No independently logged feeding/stress/stimulus timing is supplied in the
  interoperable source package. Even though the Oxford experiment includes
  food and obstacles, **event times are not inferred** from the video name.
- No physical underwater calibration, refractive stereoscopy, surveyed XYZ,
  or physical cm/s estimation is attempted. MP4 video-local PTS is not
  camera-exposure-synchronized UTC.
- No causal, replicated treatment, fish stress/welfare or husbandry outcome
  is inferred.

## Exact executed scientific stages

1. Download exact previously completed real model-and-ByteTrack benchmark
   artifact and preserve its original source report without modification.
2. Download original 15-video ZIP afresh; SHA-256-check original ZIP and
   exact clip member. Re-probe all 149 source-frame video-local PTS with
   FFprobe against the archived manifest; reject mismatches.
3. Read every actual ByteTrack row and inspect its original frame index,
   source PTS, confidence, bounding-box geometry, and per-frame identity.
   Verify source report hashes; fail on duplication, time mismatch, missing
   observations in the original source schedule, or invalid positions.
4. Convert the *original genuine ByteTrack track file* to standard MOT
   with explicit 1-based frame origin; do not replace or relabel identities.
5. Use the universal Research Bundle v1 converter with kind mot_bytetrack,
   original source PTS, and the historical original model source report.
6. Import into R using aqt_research_bundle_import.
7. aqt_trajectory_qc(max_gap_s=.15) then aqt_qc_review() — automatic
   screening only; no fabricated manual visual review decisions.
8. aqt_research_analyze() computes qualified movement and explicitly
   refuses unsupported event/functional/experimental inferences. The
   schooling profile is not selected because the recorded trial is one fish.
9. aqt_research_publish() renders actual real-data PNG/vector-PDF movement
   plots, QC coverage, data eligibility and manuscript captions.
10. Export complete source and scientific provenance metadata, actual
    numerical results, review accounting and cryptographic file digests.

The result bundle is a GitHub Actions artifact; the source ZIP and video
are deliberately not uploaded. The generated RDS/CSVs/plots contain only
real source model-generated coordinates, not synthetic demonstration fish.

## Direct evidence and interpretation

The GitHub Actions workflow is
.github/workflows/real-fish-research-demonstration.yml

The downloadable successful-run artifact is named:
milestone05-real-oxford-published-R-scientific-report

Its RESULTS/ directory contains:
- M05_SUCCESS.json (final verified integrated real analysis marker)
- REAL_STUDY_RESULTS.json (the actual observed counts, pixel measures and
  source-reviewed detector agreement, with explicit validity flags)
- REAL_OBSERVED_PATH_SUMMARY.csv (all source-ID-local measured path lengths)
- PROFILE_STATUS.csv (each permitted/blocked profile)
- README_REAL_FISH_STUDY.md (human-readable evidence restrictions)
- source_evidence/REAL_SOURCE_AUDIT.json (authentic original video and
  original model/tracker provenance)
- publication/analysis/ (Milestone 03 original source RDS, QC records,
  scientifically screened measures and checksummed analysis manifest)
- publication/figures/ (real source-measurement PNG/PDF figures)
- publication/tables/ and publication/REPORT.md (manuscript-style
  figures, tables and captions)
- publication/PUBLICATION_MANIFEST.json (SHA-256 checksums for all
  published outputs)
- oxford_research_bundle/ (loss-audited Research Bundle v1 with source
  frame manifest, reviewed input observations and original metadata)

No figure/movement step is fabricated across missing source frames.

## Scientific acceptance: NOT interchangeable with software passing

A successful M05 run establishes:
- Real original video and historical independently executed model/tracker
  artifacts were integrity-checked and matched to 149 original frames.
- The Python to R data contract works on authentic external fish tracks.
- Native R metrics use original timestamps, only eligible source observations,
  and strict frame-adjacency.
- Native PNG/PDF figures and numerical results describe genuinely observed
  detector/tracker outputs, with research provenance preserved.

It does NOT establish:
- Independently certified fish identity or official HOTA/IDF1
- New, genuinely untouched holdout generalization
- Biological accuracy of schooling or multi-fish interactions
- Physical tank units, XYZ, true fish speed under calibrated geometry
- Experimental stimulus effects, causal claims or welfare/feeding responses
- A manuscript-quality independent biological experiment without additional
  human annotation, replication and protocol documentation

The still-needed external-validation work should therefore be a NEW
recording, wholly separate from earlier development/tuning, with a
predesignated frozen model/tracker, genuine source clocks, blinded manually
adjudicated fish tracks and at least one independent experimental unit for
appropriate inference. This cannot be inferred from an old exposed clip.

## Provenance references

Oxford original: Dutta, Pérez-Campanero, Taylor, Zisserman and Newport,
Detect+Track: robust and flexible software tools for improved tracking and
behavioural analysis of fish, Royal Society Open Science, 2025.
Source and data: https://www.robots.ox.ac.uk/~vgg/research/fish/
The Oxford group should be cited in any reuse of the real source data.
