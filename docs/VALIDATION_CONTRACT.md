# Independent detection and identity-tracking validation

## Scientific scope

AquaTrajectories Wave 2 distinguishes:

1. **Detector quality** using independently annotated rectangular bounding boxes.
2. **Tracker identity quality** using independent manually verified IDs and x/y coordinates.
3. **Scientific validity**, which neither of the above establishes by itself.

## Detection

The reference and prediction tables contain session_id, camera_id, frame_id,
class_id, xmin, ymin, xmax and ymax. Predictions additionally require
confidence in [0,1]. Evaluate precision, recall, F1 and 101-point AP over
user-declared IoU thresholds. This AP implementation does not reproduce
all COCO ignore/crowd/area/maxDets rules.

Bounding-box matches maximize valid one-to-one match cardinality separately
for each class, camera, session and frame. All scores depend on independent
annotations and chosen IoU/confidence thresholds.

## Sparse annotation

If only 30 frames of a 20-minute recording were manually reviewed, create
aqt_evaluation_frames() with these 30 (including manually checked empty frames),
then pass the manifest via evaluated_frames= to detector and tracking evaluators.
Predictions outside these frames must not be counted as false positives.
Do not assume omitted frames were verified empty.

## Identity tracking

Point tracking uses matched 2D positions under an explicit distance threshold
in common units. The per-session/camera IDF1 score is based on the global
optimal one-to-one identity assignment over matched observations. This is
different from detection precision, and duplicate IDs within one frame are
invalid.

The reported adjacent_id_switches counts only consecutive, successfully
matched reference frames. It is NOT claimed to reproduce the formal CLEAR MOT
switch conventions. HOTA, standardized MOTChallenge exports and full
cross-tool TrackEval validation remain open research tasks.

## Provenance and manual corrections

File MD5 checks detect accidental source changes but are not cryptographic
authenticity controls. Keep original videos, annotation versions and model
weights unchanged. Corrections must record reviewer, reason, scope and the
original ID; the software never invents corrections.

## Future verification

Known-truth R tests are necessary but not sufficient. Compare matched clips
against independently annotated real underwater fish video and, where
compatible, external TrackEval metrics. Report separate performance for
species, shadows, camera views, crossings, and occlusion conditions.
