# AquaTrajectories Research Bundle v1 — universal tracking-data interchange

**Engineering format v1.0.0. Not a certification of animal identity, tracker accuracy, or camera synchronization.**

The research bundle is a versioned, checksum-audited bridge from external YOLO + ByteTrack, YOLO + BoT-SORT, or idtracker.ai 6.x tracking results to AquaTrajectories native R trajectory analysis.

## Required frame manifest

A complete CSV with exact columns:

    session_id,camera_id,frame_id,time_s,width_px,height_px
    S01,TOP,0,0,1920,1080
    S01,TOP,1,0.0333667,1920,1080
    S01,TOP,2,0.0671000,1920,1080

Frame numbers are zero-based, ordered and unique; gaps are allowed. Timestamps must come from the supplied recording or independently recorded timing; the converter **never invents time by dividing frame number by FPS**. Include frames without detections. If time is unavailable, leave every time_s blank and use --time-status unknown; R returns observations but tracks=NULL and prevents time-based movement analysis. Source PTS does not certify common shutter exposure across cameras.

One bundle is for one session and one camera. Never equate camera-local track IDs across sessions without separate evidence.

## Python import commands

ByteTrack MOT result (frame,id,left,top,width,height,confidence,...):

    python inst/python/aqt_research_bundle.py create \
      --kind mot_bytetrack --source bytetrack.txt \
      --frames top.frames.csv --frame-origin 1 \
      --session-id S01 --camera-id TOP --time-status source_pts \
      --model fish_best.pt --tracker-config bytetrack.yaml \
      --out result/top_bytetrack

BoT-SORT MOT result:

    python inst/python/aqt_research_bundle.py create \
      --kind mot_botsort --source botsort.txt \
      --frames top.frames.csv --frame-origin 1 \
      --session-id S01 --camera-id TOP --time-status source_pts \
      --out result/top_botsort

idtracker.ai 6.x tidy CSV (frame,time,individual,x,y,probability):

    idtrackerai_format path/to/session --formats csv_tidy
    python inst/python/aqt_research_bundle.py create \
      --kind idtracker_tidy --source trajectories_tidy.csv \
      --frames top.frames.csv --frame-origin 0 \
      --session-id S01 --camera-id TOP --time-status source_pts \
      --out result/top_idtracker

The frame origin is **explicit**. Inspect the actual idtracker.ai output before choosing 0 or 1. Its source time column must agree with the frame manifest. Missing source positions remain missing and identity probabilities remain distinct from detector confidences.

YOLO long CSV requires frame_id,track_id,x_px,y_px and may contain confidence/detection_confidence and complete bbox_left/bbox_top/bbox_width/bbox_height fields:

    python inst/python/aqt_research_bundle.py create \
      --kind yolo_csv --source yolo_tracks.csv \
      --frames top.frames.csv --session-id S01 --camera-id TOP \
      --time-status source_pts --out result/top_yolo

To declare externally checked timing, provide --time-status externally_verified --clock-evidence PATH, which records the evidence SHA-256 but does **not** independently verify physical synchronization. Unverified source times can be retained with --time-status unverified; unavailable times must remain empty with --time-status unknown.

## Folder and data contract

    research_bundle/
      frames.csv
      observations.csv
      manifest.json

Canonical observation columns:

    session_id,camera_id,track_id,frame_id,time_s,x,y,observed,
    quality_flag,position_definition,bbox_left,bbox_top,bbox_width,
    bbox_height,detection_confidence,identity_probability,source_row

- Positions are **image pixels**. MOT boxes become explicitly marked bounding-box centres; idtracker/YOLO coordinates remain their original reported XY.
- Boxes that were not supplied stay absent. No 3D depth or physical centimetres are invented.
- A detector score and an idtracker identity-assignment probability are retained in **separate fields**. Unknown values remain blank.
- Identifiers are retained as strings, including leading zeros. No across-camera identity claim is made.
- Observations start with quality_flag=unreviewed; missing positions have source_missing_position. The flags do not certify biological validity.
- Metadata records exact output byte SHA-256 and declared source-file, model and tracker-configuration hashes; original source binaries are not copied into this small interchange folder.
- An existing destination directory is never overwritten.

## Native R scientific-layer workflow

    library(aquaTrajectories)
    bundle <- aqt_research_bundle_import("result/top_bytetrack")
    stopifnot(bundle$output_sha256_verified)
    print(bundle$metadata)
    print(bundle$observations)
    if (!is.null(bundle$tracks)) {
      kin <- aqt_kinematics(bundle$tracks,max_gap_s=.2)
      paths <- aqt_path_summary(bundle$tracks,max_gap_s=.2)
      aqt_plot_paths(bundle$tracks)
    }
    aqt_research_bundle_export(bundle,"result/top_bytetrack_copy")

The export preserves verified original file bytes; it does not silently disguise edited observations as raw source data. Modified measurements should be stored as a separately versioned research-derived dataset.

The existing Python PyAV video runner now supports --tracker bytetrack.yaml or --tracker botsort.yaml, exports source-frame PTS and MOT predictions, and can feed this converter. Keep the original class-ID sidecar alongside its original run.

## Qualification and scientific boundaries

Dedicated GitHub Actions tests create synthetic ByteTrack, BoT-SORT, idtracker.ai and YOLO outputs in Python, independently import them in R, and verify complete byte-preserving roundtrips. They test missing positions, zero-padded IDs, file tampering, unknown timing, and duplicate IDs. This is engineering validation, **not** independent accuracy validation on fish videos.

References:
- https://www.idtracker.ai/latest/user_guide/output_structure.html
- https://docs.ultralytics.com/modes/track/
- https://github.com/JonathonLuiten/TrackEval/blob/master/docs/MOTChallenge-format.txt
