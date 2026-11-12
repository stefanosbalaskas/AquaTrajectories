# Wave 14A — Fraunhofer original multi-fish benchmark source discovery

Fraunhofer HHI's [Fish Tracking and Segmentation Dataset](https://cvg.hhi.fraunhofer.de/FishTracking.htm) offers **two separate crowded-ricefish annotated recordings** at 2448×2048, 101 frames each, published persistent fish IDs (A: 256 unique IDs; B: 45 unique IDs). The original site recommends Datumaro for identity-preserving annotation data and MOT for tracking evaluation.

This wave **fetches the real original source webpage**, rather than inventing an archive URL. A stdlib HTMLParser obtains the literal original `href` values for MOT, Datumaro and video resources and records the original source page SHA-256. CI stores only the metadata.

This source-discovery step is not itself a fish model run. Until original MOT or Datumaro ZIP bytes are acquired, audited and matched to frames, it cannot claim HOTA, IDF1 or fish identity accuracy.

## Next exact acceptance

1. Download original A and B MOT/Datumaro dataset archives discovered from these actual HTML links, preserving source ZIP SHA-256 and license.
2. Inspect the **actual** annotation files for source frame origins, all zero-fish frames, per-frame repeated IDs, video timebase and whether 'MOT' annotations actually preserve consistent identities (prefer original Datumaro where they differ).
3. Generate two model-based fish detector output sets with **frozen** weights and all observed source frames. Use Oxford EfficientDet as external domain-transfer baseline, not an automatically suitable model for ricefish.
4. Run ByteTrack and a second tracker, use official TrackEval HOTA, DetA, AssA, IDF1 and CLEAR IDSW on frame-disjoint data. Detection-oracle comparisons must be labelled oracle, not model accuracy.
5. Human-review ambiguous or occluded IDs without revealing tracker output and reproduce sequence-level output SHA-256.

## Scientific boundaries

The original 3D-ZeF reconstructed fish positions are not surveyed physical XYZ. Fraunhofer ricefish has a **single camera** per recording, not hardware-synced stereo. A fish tracker’s IDs must never be treated as true biological identity absent independent ground-truth labels. This work remains part of issue #46 and the nine-milestone issue #51.
