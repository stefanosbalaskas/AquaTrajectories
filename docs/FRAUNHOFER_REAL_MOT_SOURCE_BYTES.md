# Wave 14C — original Fraunhofer A/B crowded-fish MOT bytes

This wave executes a **genuine source-file download** for the original
Fraunhofer HHI Sulawesi ricefish A/B MOT archives, using exact original
URL values discovered in Wave 14A's HTML source audit.

Original landing page:
https://cvg.hhi.fraunhofer.de/FishTracking.htm

Original download links extracted from source HTML:

- https://cvg.hhi.fraunhofer.de/FishTrackingData/video_a/mot_a.zip
- https://cvg.hhi.fraunhofer.de/FishTrackingData/video_b/mot_b.zip

The source reports 101 frames per recording, 256 persistent IDs in A,
45 in B, 2448×2048 source frames, and semi-automatic source annotations
with frequent occlusions. The source asks users to cite Palm et al.,
*Video-Based Locomotion Analysis for Fish Health Monitoring*,
VISAPP 2026.

## Strict provenance caveat

**TLS verification fails** for the HHI site on the CI Linux runner with
`unable to get local issuer certificate`. The workflow therefore
downloads with `curl --insecure` for **inspection only**, and every
derived report sets `original_download_peer_tls_verified=false`.
No result from this source may yet be represented as authenticated
or independently scientifically certified without separately validating
archive hashes or confirmed source integrity.

For each actual downloaded ZIP, the script enumerates safe member
paths, original ZIP SHA-256, member formats, video/image contents,
any actual original `gt/gt.txt` MOT track rows, unique fish
identities and frame indices, duplicate (frame,id) entries and source
confidence/ignore flag distribution. It outputs **only** audit JSON,
never republishing original licensed video/image/annotation bytes.

## Remaining evaluation

- Compare archive contents with the recommended original Datumaro A/B
  archives, cross-check consistent fish IDs and ignored/difficult boxes.
- Create explicit original fully annotated 1..101-frame manifests,
  only after source annotations are verified.
- Run independently model-generated fish detections through actual
  ByteTrack and second tracker, then official TrackEval HOTA/DetA/
  AssA/IDF1/CLEAR. Oracle original GT boxes, if used for association
  comparison, must be named **detection oracle**.
- Perform independent biological ID label review and error strata
  for camera reflections, occlusions and crossing fish.
- No multi-camera hardware time alignment, refraction calibration,
  underwater physical XYZ, or fish welfare conclusion can be
  established from these single-view source annotations alone.

Issues: https://github.com/stefanosbalaskas/AquaTrajectories/issues/46
and https://github.com/stefanosbalaskas/AquaTrajectories/issues/51.
