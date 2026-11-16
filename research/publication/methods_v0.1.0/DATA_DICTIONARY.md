# Data and reproducibility dictionary

The `schemas/` files are **headers only**. They define what an eventual independent empirical manuscript needs to record, not what has been observed.

| Artifact | Core fields | Integrity and analysis rules |
| --- | --- | --- |
| `source_inventory.csv` | source ID, license, original file path, SHA256, type, camera/tank/recording scope | hash real original bytes; never distribute rights-limited videos or weights by default |
| `split_registry.csv` | study/recording/tank, split, pilot/training/holdout scope, status | no frames from the same heldout recording in training/calibration, no downstream test tuning |
| `model_registry.csv` | model name, checkpoint hash, original training domains, class map, preprocessing, thresholds, implementation version | freeze exact weights before heldout; audit training-data overlap |
| `evaluated_frames.csv` | session/camera/frame, reviewed status, timestamp, frame image dimensions, reviewer | record *all* intended evaluated frames incl independently verified zero-fish frames |
| `reference_boxes.csv` | frame ID, species/class, bbox pixels, annotator, reviewed/unknown, source | source GT/predictions stored separately; annotators blind to evaluated output |
| `reference_identities.csv` | recording/frame, scoped persistent fish reference ID, identity certainty, annotator | unknown identity remains unknown; no forced matching |
| `predictions.csv` | model hash, frame/box, score, class, assigned camera track | entirely generated without ground truth in end-to-end experiment |
| `pulse_markers.csv` | camera-local timestamp, physical event ID, fit/holdout partition, external pulse reference | independent verified shared physical event and timebase |
| `physical_targets.csv` | surveyed XYZ, pixel observations in each camera, units, target assembly, fit/holdout, survey-record hash | independent surveyed XYZ; fit and holdout *assemblies* disjoint |
| `annotation_audit.csv` | reviewer ID, blinded status, adjudicator, unknown/occluded, review hash and date | independent review provenance; source model-assisted labels identified |
| `study_design.csv` | tank, treatment, randomization unit, allocation record, ethics reference, events | no causal inference without replicated randomized units and approval |
| `analysis_result_registry.csv` | estimate, units, method, interval, exact source files/hashes, reviewer signoff | a result is NOT admissible without a source chain and independent validation status |
| `study_evidence.json` | externally observed complete evidence records | **NOT PROVIDED**; never fabricate to make an audit succeed |

## Standardized scope and units

- Original image bounding boxes: `xmin,ymin,xmax,ymax` in raw source **pixels** with declared image origin and dimensions.
- Tracking IDs are **camera-/recording-scoped**, unless a separate verified correspondence table is provided.
- Frame IDs must preserve original numbering plus any explicit normalization table. Video-local PTS is not necessarily physical shutter time.
- `truth_x,y,z` require an independent spatial survey with an explicit physical unit. No invented `z=0` source camera depth.
- A fish may be observed but its biological ID unknown; it must be possible to represent that state.
- A target measured repeatedly within one board is not an independent board. The board and tank are named in the split.
- A synthetic teaching file is never entered as a real study observation.

## Data retention

Prefer a protected access-controlled store for original fish media, camera/survey files, annotator reviews and ethics documents. Release source metadata, derived permissibly redistributable predictions and aggregated metrics only after checking licenses. For multi-collaborator studies, preserve signed approvals, dates, immutable external IDs and a log of every label correction.

## Truth status schema

Use one of `source_annotations_unverified`, `human_reviewed_not_blinded`, `prediction_blind_independent`, `physical_survey_independent` or `not_available`; do not convert between statuses merely because an automated check passes.

## Version freeze

Recording hashes, GT versions, the model checkpoint, TrackEval revision, package version, refraction configuration, analysis code, OS/R/Python environment and exact statistical outputs should be frozen as part of the protocol's eventual registered analysis. A mere Git tag does not independently authenticate external data.
