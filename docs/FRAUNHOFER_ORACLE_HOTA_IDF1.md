# Wave 14D — genuine crowded-ricefish oracle identity association benchmark

**Purpose:** Run two independent tracking-association methods on the
**original**, densely populated Fraunhofer HHI Sulawesi ricefish MOT A/B
annotations and score their *assigned identities* using the unmodified
official TrackEval HOTA/IDF1/CLEAR implementation. The two original downloaded archives have 101 original image frames each;
**actual raw MOT GT** has **260/45 unique fish IDs (A/B)** and **9,214/1,969
annotations**. The source website's 256 fish IDs for A does not agree with
its download's 260 IDs. Actual source A frame labels are 43,450–43,550 and
B 13,654–13,754. The evaluator maps these original source frames to local
1–101 **only after verifying exact source JPEG filename and GT coverage**.
Original raw absolute frame provenance remains recorded alongside the
original ZIP SHA256. The fish are frequently occluded.

## Critical distinction: oracle input, not original model detections

To isolate **identity association**, both ByteTrack and IoU/Hungarian
receive exactly the **source annotated fish bounding boxes** in each
frame. The original real fish IDs are **never supplied to either
tracker**; they are retained exclusively for scoring the independently
generated track IDs. This makes the benchmark an explicit
**perfect-detection / oracle-box association experiment**. Its
HOTA/IDF1/IDSW scores quantify association performance conditional
on the source boxes, NOT end-to-end independent detection+tracking
accuracy. A comparison against imperfect model-generated boxes must
be conducted separately.

The comparison trackers are:
- `supervision==0.26.1` genuine ByteTrack with a separately
  initialized tracker for each source fish recording; input
  confidence 0.99 for every oracle annotated box.
- A deterministic IoU/linear-Hungarian baseline with threshold
  0.1 and maximum five missing frames, using no image data or
  source GT track IDs.

Exact official metrics: `JonathonLuiten/TrackEval` at commit
`12c8791b303e0a0b50f753af204249e622d0281a`,
using 1-based fully included sequence frames, frame-local fish boxes,
and separate source GT ID labels. Reports HOTA, DetA, AssA, HOTA@0.50,
IDF1, MOTA, IDSW, true/false positives and counts.

Original source archive URLs are obtained from the actual official
Fraunhofer HTML page, verified as literal `href` in Wave 14A:
- A: https://cvg.hhi.fraunhofer.de/FishTrackingData/video_a/mot_a.zip
- B: https://cvg.hhi.fraunhofer.de/FishTrackingData/video_b/mot_b.zip

## Provenance and independent scientific limitations

The original HHI host currently fails a standard Linux CA-chain
verification; source archives are downloaded with `curl -k`
**solely for exploratory research-source execution**, marked
`source_original_tls_peer_verified=false` in every report. Hashes
are recorded and should be independently checked against verified
author releases before presenting an authenticated scientific finding.

Original fish GT is semi-automatically annotated. Source ID
correspondence in heavily overlapping fish has not been independently
blind-adjudicated for AquaTrajectories. Source frame completeness
should be confirmed from the original video/images, not merely
published counts; the script records that status as false.
Model-origin detections were NOT produced on Fraunhofer video.
The frozen Oxford EfficientDet that ran on Oxford's own video is
not automatically validated on dense ricefish.

This is **an important real-data identity-association submilestone**
if both CI scripts execute successfully. It cannot close priority
1's heldout model detector accuracy, full priority 2 end-to-end
tracking HOTA, actual hardware cross-camera synchronization, measured
underwater physical XYZ or fish welfare/ACI validation.

See https://github.com/stefanosbalaskas/AquaTrajectories/issues/46
and https://github.com/stefanosbalaskas/AquaTrajectories/issues/51 .

## Verified exact source bytes (Wave 14C)

Original A ZIP SHA-256:
`18c39619b1f84ea774f16fedfac5911d92de86ab7da4aa03cf365b9b4be58ceb`.
Original B ZIP SHA-256:
`29b1396397b5ba74450cc1388a0be94b2920de1c45530b8e2d3b184fd07adb9d`.
The source website has invalid default CA-chain verification; source bytes
are reproducible across our audits, but upstream peer TLS authentication
remains externally unverified.
