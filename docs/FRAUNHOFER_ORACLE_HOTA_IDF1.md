# Wave 14D — genuine crowded-ricefish oracle identity association benchmark

**Purpose:** Run two independent tracking-association methods on the
**original**, densely populated Fraunhofer HHI Sulawesi ricefish MOT A/B
annotations and score their *assigned identities* using the unmodified
official TrackEval HOTA/IDF1/CLEAR implementation. These two real
sequences have 101 annotated frames each and source-published 256/45
fish IDs (A/B), with frequent occlusions.

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
