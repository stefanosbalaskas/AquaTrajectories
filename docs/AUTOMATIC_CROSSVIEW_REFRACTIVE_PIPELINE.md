# Wave 15A — native automatic cross-camera fish matching and refractive 3D

## Delivered native R functions

- `aqt_refractive_view_candidates(view_a, view_b, camera_a, camera_b)`: generates source-time-compatible cross-view candidate fish pairs, uses the existing physically declared one- or two-interface refractive ray models and reports actual ray separation and reconstructed XYZ. No borrowed camera-local ID is interpreted as biological identity.
- `aqt_crossview_auto_associate(candidates)`: turns temporal geometric support into stable one-to-one camera-local track links. It withholds matches that have geometrically unresolved competing fish identities; the output remains explicitly **provisional**.
- `aqt_auto_refractive_pipeline(...)`: chains the two stages with the existing `aqt_refractive_reconstruct_tracks()` and `aqt_refractive_track_quality()` to produce native 3D `aqt_tracks`, diagnostics, candidate provenance and abstention counts. Zero matches return an explicit absence without creating fictitious fish.

Automatic assignment is **a geometrical hypothesis**, not independently certified animal re-identification: two similarly positioned fish may be exchanged at occlusions, ByteTrack itself may change IDs, 3D ray separation can be low despite erroneous camera calibration, and timestamp agreement does not prove physical exposure synchronization. The estimator refuses ambiguous equal-support alternatives when median ray-separation advantage is below a prespecified margin, but the greedy stable track matching is a baseline that may not maximize the global bipartite objective. A mature accuracy claim requires independently reviewed multi-camera individual identities.

This wave upgrades the native software API from **reviewer-selected matches only** to **automatic cross-camera assignment plus refractive 3D reconstruction**, while retaining all existing reviewer-mediated functions for adjudication. Synthetic two-fish test geometry checks exact XYZ, one-to-one timestamps, hard candidate caps, abstention on symmetrical ties, and non-overlapping timestamps returning NULL.

## Global three-or-more-camera reference-anchored fish fusion

`aqt_multiview_global_fuse()` now reconciles provisional links from
the same reference camera across **multiple independently named secondary
camera streams**. It groups 3D hypotheses by exact original source
reference-fish identity and timestamp, checks minimum distinct camera
view count and **rejects incompatible refractively reconstructed XYZ**
instead of averaging disagreement into plausible fish positions.
Accepted 3D rows receive a single stable `GLOBAL_REF_<session>_<id>`
provisional identity and a ray-separation-weighted XYZ estimate.
The separately retained `pairwise_3d_hypotheses.csv` preserves
each actual source secondary-camera triangulation; the unified
`fish_3d_tracks.csv` contains at most one global XYZ per reference
fish frame, and `rejected_multiview_3d.csv` records incompatible
cross-view source reconstructions.

This resolves global N-view **geometric integration** while leaving
physical source camera synchronization, biological ID identity and
separately measured XYZ as external validation requirements.

## Limits before feature/research release

- Camera models, undistorted source pixels, actual camera-video PTS and any physical clock alignment are **supplied**; this module does not train a detector or estimate camera intrinsics.
- The 3D result is conditional on source optical parameters and stable camera-local tracker IDs. It is not independently metrology-certified.
- Source `aqt_tracks` require upstream fish video detection and tracking from the existing `aqt_track_video.py` PyAV/YOLO/ByteTrack runner or `aqt_video_bundle_import()`. A separate integration command should orchestrate that.
- Cross-view fish association should eventually include appearance, anatomy, trajectory priors and validated probabilistic calibration beyond this geometry-first baseline.

See scientific gates [#46](https://github.com/stefanosbalaskas/AquaTrajectories/issues/46) and [#51](https://github.com/stefanosbalaskas/AquaTrajectories/issues/51). Passing software CI must not automatically certify external biological fish identities.

## Integrated source pipeline optional uncertainty and events

`inst/python/aqt_video_to_3d.py` now supports:
- `--mode infer`: 2–6 original user-supplied videos, frozen fish-specific
  YOLO weights and original input video/model SHA-256 → exact PyAV
  decoded PTS & ByteTrack source bundles → native R auto crossview
  fish association/3D source output.
- `--mode prepared`: accept independently SHA-verified previously
  tracked video bundles to reproduce the R geometry without rerunning
  the computationally expensive detector.
- `--events-csv /data/original_events.csv`: optional original
  `event_id,time_s,event_type`, validated and copied with its
  unchanged SHA-256 into the atomic result bundle; event-source
  timing has **not** been externally certified.
- `--empirical-source-csv /data/real_joint_error.csv`: optional
  original tank-heldout source truth/ID/calibration residual rows for
  Wave15B's actual empirical joint uncertainty module. It generates
  `joint_empirical_calibration.json` and adds source SHA and
  independent-accuracy FALSE qualifiers to the same atomic
  video→3D output; if the independent external original error source
  or Wave15B module is missing it fails explicitly, never invents
  uncertainty or silently defaults to a confident prior.

3D results are separated into `pairwise_3d_hypotheses.csv` with
unaltered source camera contributions, `fish_3d_tracks.csv` with
globally reference-anchored provisional fish tracks after checking
multi-camera disagreements, `rejected_multiview_3d.csv` recording
inconsistent source hypotheses, and complete original 2D frames,
tracks and camera link records. Every derived output is SHA-256
tracked in `evidence_sha256.json`. The browser in Wave15C
automatically accepts these file layouts when selected locally.
