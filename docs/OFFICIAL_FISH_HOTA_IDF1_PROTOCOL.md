# Wave 14B — genuine official TrackEval fish identities (metric contract)

This module runs the **unmodified original** `JonathonLuiten/TrackEval`
metric classes `HOTA`, `Identity`, and `CLEAR`, at source commit
`12c8791b303e0a0b50f753af204249e622d0281a`.

It is a ready-to-run scoring bridge for **model-generated fish trajectories
with independent real fish GT**. Synthetic known-truth tests prove that
identity continuity, switches and detection accuracy yield expected
HOTA/DetA/AssA/IDF1/MOTA values; **they are not independent experimental
fish-tracker accuracy.**

## Required data

- A manifest including *every* evaluated frame starting at 1, including
  zero-fish frames: `frame,review_status[,reviewer_id]` where every
  `review_status=fully_annotated`. No partial labels or unlabeled frames.
- Ground truth `gt.txt` and algorithm-generated tracker `pred.txt` in
  MOT challenge first six fields: `frame,id,x,y,w,h`. GT confidence, if
  present, must be exactly 1; manual review required for ignored/difficult
  classes rather than silently dropping them.
- All coordinates use original image pixels; fish IDs must be stable
  across each recording, not mixed across unrelated tanks. Each source
  frame+fish ID pair is unique, including the observed zero-fish frames
  explicitly declared in the manifest.
- Record exact source dataset/video/annotation hashes separately.

## Command

    python inst/python/aqt_official_fish_trackeval.py \
      --gt /data/sequence/gt/gt.txt \
      --pred /data/frozen_tracker/seq.txt \
      --frames /data/sequence/frames_reviewed.csv \
      --sequence RICEFISH_A \
      --source-kind model_tracker \
      --reference-blindness unverified \
      --out /data/evidence/trackeval_metrics.json

The resulting report includes **unmodified TrackEval HOTA average over
thresholds 0.05:0.05:0.95**, DetA, AssA, LocA, HOTA@IoU=.50,
global IDF1 and integer IDTP/IDFP/IDFN, CLEAR MOTA and IDSW,
GT and tracker observation counts and all input SHA-256 digests.

For an **oracle detection association test**, use
`--source-kind oracle_box_association`; such a score evaluates
association only under perfect ground-truth detection. It must never
be represented as independently observed fish detection accuracy.
The report retains this source condition.

## Scientific qualification ladder

1. **Software contract (this wave):** synthetic perfect and deliberate
   identity-switch fixtures run through the actual pinned TrackEval
   implementation; empty frames and duplicate IDs are checked.
2. **Real source validation:** acquire original Fraunhofer HHI Datumaro/MOT
   archives A and B (101 frames each, published fish identities) from
   https://cvg.hhi.fraunhofer.de/FishTracking.htm, record original source
   ZIP SHA, validate all IDs/occlusions, ensure identical evaluation
   frame manifest and class/ignore policy.
3. **Association-only comparison:** drive ByteTrack and a second
   association algorithm with independently annotated original fish boxes,
   as **detection-oracle** experiments; record real HOTA/IDF1 without
   claiming fish detector validity.
4. **Actual end-to-end models:** freeze fish detector weights, run
   inference on heldout original video pixels, track those predictions,
   score actual HOTA/IDF1 against independent non-leaking fish IDs and
   independently check worst occlusions.
5. **External scientific certification:** expert correction/blinded
   labels; recorded dataset licensing and splits, multiple sequences
   and tank-level uncertainty. Physical underwater XYZ is separately
   assessed using surveyed hardware calibration targets.

The official TrackEval HOTA implementation is **not itself a
benchmark organizer submission** or proof that source-specific
difficult/ignore annotations were preprocessed correctly. The source
paper's human-reviewed labels may still be model-assisted, and
independence must be evaluated before claiming certified accuracy.

Current blockers: https://github.com/stefanosbalaskas/AquaTrajectories/issues/46
