# Data schemas and measurement limitations

## Canonical trajectories
Columns: session_id, camera_id, track_id, time_s, x, y, z (optional), observed (optional).
Identity is scoped to session and camera. Units are px, cm or m, and spatial coordinates identify image or tank spaces.
3D tracks require explicit physical/tank coordinate labels; z is NA for 2D tracks.
Consecutive timestamps for a scoped track must be unique. Data are sorted by track/time.
Unmodified source detections, annotation references and model versions should be retained outside the coordinate table.

## Kinematics
Positions must be calibrated before physical claims about speed. Distances are Euclidean; velocity uses actual dt.
No missing segment is silently connected, and max_gap_s can reject observed gaps.
Derivatives can greatly amplify camera jitter. Current heading and turn rate use the XY projection; 3D orientation/curvature requires separate definitions.
Group metrics require simultaneous time stamps; do not conflate one frame with one experimental replicate.

## Sync
aqt_sync_fit maps camera time to a reference clock using shared markers. Two or more markers permit affine drift estimation; one marker permits offset only. Recorded timestamps may still differ from exposure midpoints and dropped or variable-rate frames may invalidate naive frame-index timing.

## Geometry
aqt_triangulate_pairs requires externally known correspondences, synchronized observations, and calibrated pinhole projection matrices, all in a common coordinate system. It does not calibrate cameras, solve identity matching, or model underwater optical refraction. Small reprojection error is NOT sufficient evidence for accurate fish positions. Full 3D trajectories require additional validation.

## Events and inference
Point and interval events are supported. Overlapping events duplicate observation/event rows explicitly, without implying statistically independent rows.
All features currently descriptive. Fish welfare assessment needs biological validation; tank-level treatment assignment cannot be assessed using frame count as an independent sample size.


## Independent ground-truth evaluation: Wave 2

Fish reference bounding boxes and predicted bounding boxes must use identical
pixel coordinate frames. IoU class-aware matching is one-to-one; detection
AP uses a declared 101-point interpolation and is not identical to all
COCO benchmark conventions.

Tracking validation uses externally verified framewise fish identities and
point locations. Every identity is scoped by camera and session. Global
identity F1 (IDF1) is computed from maximum-weight one-to-one identity
assignment. Adjacent ID switches omit unmatched gaps: they are NOT
official CLEAR MOT ID-switch scores; HOTA remains external TrackEval work.

Sparse truth annotation must pass an explicit manifest from
aqt_evaluation_frames(), listing ALL fully reviewed frames including
empty ones; otherwise false positives from unannotated frames are invalid.
MD5 manifests detect file changes but do not authenticate source material.
