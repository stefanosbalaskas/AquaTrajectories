# Real fish datasets and GoPro video structures — evidence-based audit
Audited 12 November 2026. This document distinguishes actual external file reads, documented file structures, and datasets whose archives have not yet been downloaded. No real fish video processing, independent 3D positional accuracy, or model performance is claimed.

## 1. GoPro official sample — real GPMF raw payload inspected

Official repository: https://github.com/gopro/gpmf-parser/tree/main/samples

The public GitHub tree confirms hero5.mp4 (11,581,756 bytes) and hero5.raw (4,792 bytes). Exact upstream Git blob SHAs: hero5.mp4 11e80a54756827b01ea4375764a4bc2458b2443f; hero5.raw 338d94bd94449b80ced5ad6e63c1647323ecb79e. The real binary hero5.raw was retrieved through the GitHub repository connector and parsed as big-endian GPMF KLV. The full MP4 was NOT downloaded or decoded in this audit.

Observed top-level key DEVC with nested STRM and metadata keys DVID, DVNM, TICK, TSMP, STNM, TMPC, SIUN, SCAL, UNIT, GPSF, GPSU, GPSP. Sensor KLV descriptors in the one observed payload:

| Sensor key | KLV type | Bytes per sample | Repeat count in inspected payload |
| --- | --- | ---: | ---: |
| ACCL | signed int16 | 6 | 199 |
| GYRO | signed int16 | 6 | 399 |
| GPS5 | signed int32 | 20 | 18 |
| ISOG | float32 | 4 | 24 |
| SHUT | float32 | 4 | 24 |

These are *payload sample counts*, not certified sample rates. GoPro telemetry payloads are stored in separate MP4 tracks from video. Camera-local PTS, GPMF IMU times, absolute GPS time and real shutter exposure phase cannot be treated as identical. Having two GoPro clips does not demonstrate synchronized exposures. See https://github.com/gopro/gpmf-parser/blob/main/README.md.

New diagnostic: inst/python/aqt_probe_recording.py (requires external ffprobe for MP4 only). Commands:

    python inst/python/aqt_probe_recording.py --video /data/hero5.mp4 --scan-frames 80 --sha256-video --output /data/video_report.json

    python inst/python/aqt_probe_recording.py --gpmf-raw /data/hero5.raw --output /data/gpmf_report.json

It reports codec streams, the gpmd FourCC when present, camera-local PTS samples, irregularities, and nested GPMF KLV sample shapes. It never asserts that its inspected timestamp subsample is the complete recording or that physical exposure clocks agree.

## 2. FishSizing: real published stereo calibration and measured fish lengths examined

Primary source: https://github.com/Caterina1996/fish_sizing/tree/paper/paper/paper_dataset/dataset_to_zenodo
Large data volume: https://zenodo.org/records/19408363

Actual files read via GitHub: calibration left.yaml and right.yaml for dataset_1/2024_11_12; fish_gt_measures.csv; Dataset_Summary_Dataset_A.csv; model_tracking_annotations.json; and a real per-frame length-results CSV. Two unmodified published camera YAMLs were copied to tests/fixtures/fishsizing/ with upstream git SHA provenance.

Real YAML keys: camera_matrix (K 3x3), distortion_coefficients (D 1x5), distortion_model plumb_bob, rectification_matrix (R 3x3), projection_matrix (P 3x4), camera_name, image_width 2048, image_height 1536. The observed right P includes x translation -179.77544, but its *physical translation unit is not explicitly declared* in the YAML. Underwater water/glass refraction and separate surveyed 3D targets are needed before physical XYZ certification.

Exact fish length CSV columns: Dataset,Identifier,Species_Common_Name,Species_Scientific_Name,Total_Length_cm. Example actual length representation: quoted 31,5 means 31.5 cm. The study's recording indexes also contain decimal commas in duration and FPS. A documented recording includes 552 left images and 553 right images: pairing camera frames by array position would be unsafe. Preserve ROS message-header stamps for synchronization.

Model tracking JSON associates visual model track IDs with externally identified specimen labels (e.g., Fish 1, Red Tag and not_a_fish). The results CSV contains frame IDs such as frame_1, model track_id including -1, raw_length, spine_length, gt and abs_error_cm. These are tracking/size evaluation structures, not surveyed XYZ truth for every fish-centroid position.

Crucial distinction: FishSizing Dataset A uses post-mortem fish posed to simulate swimming for visual geometry/length analysis; Dataset B includes swimming tagged seabass. Dataset A must NOT be used to certify live fish locomotion, behavioural states or welfare.

New diagnostic: inst/python/aqt_ros_stereo_audit.py (optional PyYAML to load the actual ROS stereo YAML).

    python -m pip install pyyaml
    python inst/python/aqt_ros_stereo_audit.py --left-yaml /data/left.yaml --right-yaml /data/right.yaml --fish-lengths-csv /data/fish_gt_measures.csv --output /data/stereo_report.json

The script inspects K,D,R,P shapes, camera image geometry and decimal-comma specimen sizes. It explicitly marks baseline physical unit and underwater 3D certification as unresolved.

## 3. Candidate validation datasets

| Dataset | Source and access | Data structures supported by evidence | Suitable claim |
| --- | --- | --- | --- |
| GoPro GPMF examples | https://github.com/gopro/gpmf-parser/tree/main/samples | MP4 with telemetry, raw GPMF KLV actually parsed | GoPro container/telemetry schemas |
| Fraunhofer Sulawesi ricefish | https://cvg.hhi.fraunhofer.de/FishTracking.htm | Controlled tank videos, advertised Datumaro/YOLO/MOT formats, 101 annotated frames each; A 256 tracks, B 45 | Tank multi-fish detection, segmentation and MOT |
| MFT25 (SU-T) | https://huggingface.co/datasets/Vranlee/MFT25 | 15 sequences, 48,066 frames, 408,578 bounding boxes; HF file access is gated | Fish tracking accuracy, HOTA / IDF1 after access |
| FishTrack23 | https://openaccess.thecvf.com/content/WACV2024/html/Dawkins_FishTrack23_An_Ensemble_Underwater_Dataset_for_Multi-Object_Tracking_WACV_2024_paper.html | Approx. 850k boxes, 26k tracks; video imagery | Cross-domain fish MOT, not GoPro XYZ |
| SFISHTRACK | https://github.com/JosepSanchezCano/SFISHTRACK | README describes videos, frames, COCO JSON segmentation/track IDs, masks and metadata; actual archive not examined | Fish tracking and segmentation after download |
| TUHH zebrafish stereo 2026 | https://tore.tuhh.de/entities/product/01d8baa1-b6a5-4163-924a-01f40ff3bc81 | 67.89GB video ZIP, synchronized stereo and manual annotated frames, 2/5/10 fish | Stereo + annotation validation; no surveyed XYZ established |
| FishSizing stereo | https://zenodo.org/records/19408363 | Real K/D/R/P YAML, fish length CSV, ROS bag recording indexes, model track ID JSON read | Stereo geometry and independently measured lengths |
| MBARI DeepSea-MOT | https://huggingface.co/datasets/MBARI-org/DeepSea-MOT | Described MOV, gt.txt MOT, seqinfo.ini, YOLO labels, Pascal VOC | External MOT schema and tracking |
| Fish4Knowledge behaviour | https://homepages.inf.ed.ac.uk/rbf/Fish4Knowledge/GROUNDTRUTH/BEHAVIOR/ | Matlab fishDetections_total3102.mat trajectories/boxes without matching raw images in that subset | Trajectory-feature/class analysis, not video inference |
| Mediterranean autoUC | https://github.com/filippovarini/community-fish-detector-dataset | Third-party index describes diver-operated GoPro reef fish frames/YOLO labels | GoPro fish detection domain adaptation |
| UWslamdataset | https://github.com/gidobot/UWslamdataset | README describes stereo calibrations, time stamps and camera poses | Underwater camera metadata only, not fish trajectories |

A further **actual fish detector export** was examined from
https://github.com/tmandel/fish-detrac/blob/master/fishtrac/trackers/VFT/detections.csv .
It is a headerless five-column table containing:
frame_number, normalized_bbox_center_x, normalized_bbox_center_y,
normalized_bbox_width, normalized_bbox_height.
The upstream VFT wrapper source confirms conversion from pixel XYWH
to normalized center coordinates and subsequent conversion back using
frame width and height. This is **detection-only**, without individual
fish track IDs or detector confidence values; it must NOT be imported
as MOTChallenge identity ground truth or given fabricated confidence.

For an image of known width W and height H, convert to pixel rectangle:
xmin=(center_x-width/2)*W, ymin=(center_y-height/2)*H,
xmax=(center_x+width/2)*W, ymax=(center_y+height/2)*H.
Preserve the original frame indexing convention and attach true PTS
only if the matching video/metadata provides it.

The large fish-video and ROS bag archives were not downloaded or benchmarked here. In particular, MFT25 on Hugging Face requires accepted access conditions. Dataset licenses and train/test splits must be independently verified before reuse.

## 4. Proposed executable research workflows

### A. GoPro MP4 with trained fish detector, no independently labelled truth

MP4 -> ffprobe/GPMF structural audit -> PyAV frame PTS -> fish-specific YOLO/ByteTrack -> MOT and full acquired-frame manifests -> SHA-256 bundle check -> native R track QC. This gives an *operational test*, not detector, identity, welfare or underwater XYZ accuracy.

### B. Real fish MOT/COCO dataset with independently annotated frames

Native frames/annotations -> converter preserving original frame origins and image dimensions -> fully reviewed independent frame manifest including zero-fish frames -> detector/tracker inference -> matched per-class precision/recall/AP and externally run TrackEval HOTA/IDF1. Without physical PTS, frame IDs cannot be asserted to be precise seconds.

### C. Real synchronized stereo RGB with ROS YAML and physical fish length

ROS bag left/right image topics + true ROS image-header stamps -> synchronized pairs with declared tolerance -> K/D/R/P and verified underwater physical refraction -> observed XYZ/size inference -> heldout manually measured fish length error. The published length data do NOT by themselves validate fish XYZ coordinates. Add separate surveyed calibration landmarks, distinct fit and holdout target assemblies, depth-dependent error reporting, and real exposure synchronization tests.

### D. Independent aquaculture tank experiment

Physically and biologically validated fish tracks -> independently logged device/feeding/enrichment events -> fish-level behavioural states + missed-data sensitivity -> independently replicated tanks -> tank-level contrasts and joint uncertainty. Locomotor HMM states must not be called physiological stress without independently validated biological reference measurements.

## 5. Hard evidence gaps and acquisition priorities

1. Download official small GoPro MP4 and run metadata/timebase probe. Inspect actual codec, gpmd stream, lens settings and every video frame PTS; do not assume GoPro model metadata identifies optical glass parameters.
2. Obtain small Fraunhofer MOT/Datumaro archive; inspect frame naming, ID origin, confidence semantics, mask polygons and image dimensions. Never apply tracker detection confidence threshold to independent ground truth.
3. Acquire MFT25 only through an authorized download, record dataset license/split, and compare with official TrackEval protocol.
4. Examine TUHH synchronized zebrafish streams and frames, but do not assume these have independently surveyed physical XYZ truth.
5. Import real FishSizing ROS left/right image timestamp vectors and confirm stereo pair multiplicity and tolerances, explicitly allowing unequal frame counts. Validate fish total-length inference separately from trajectory inference.
6. Independently survey underwater target XYZ and camera positions under actual aquarium optics. At least two experimental views and multiple depth targets are needed to certify absolute 3D trajectory errors.

Passing software contracts, matched ray residuals or accurate total body length estimates does not establish independent true 3D fish trajectories.


## 6. FishSizing ROS bag stereo synchronization — executable pairer

New code: inst/python/aqt_ros_image_header_pairing.py

Its optional extract_image_headers(bag_path, left_topic, right_topic)
uses rosbags.highlevel.AnyReader on *actual* ROS1 or ROS2 image
message topics. It reads acquisition header.stamp and separately records
bag reception time in integer nanoseconds, avoiding floating-point
epoch precision loss. The raw image header is not a promise of a
physical shutter exposure and independent camera hardware sync is
still required for such a claim.

Export original left/right header records to CSV using exact columns:
frame_index,topic,header_stamp_ns,bag_time_ns,optical_frame_id
(all integer nanosecond stamps). A topic may contain more captured
images than its companion. Missing images are NOT repaired by
reassigning frame numbers.

~~~sh
python inst/python/aqt_ros_image_header_pairing.py \
  --left-csv /data/left_image_headers.csv \
  --right-csv /data/right_image_headers.csv \
  --tolerance-ns 2000000 \
  --right-to-left-offset-ns 0 \
  --output /data/stereo_header_audit
~~~

The script performs a one-to-one chronological pairing within the
explicitly chosen two-millisecond header-stamp tolerance for this
*illustrative command only*. A different tolerance must be justified
from actual hardware marker uncertainty; no universal two-millisecond
recommendation is implied. Outputs stereo_pairs.csv and an audit of
unpaired images, timestamp residuals, ROS bag receipt delays,
recording proportions and source SHA-256. Clock-offset correction is
user-provided, not automatically estimated or certified.

Important: a low header-stamp residual does not verify true exposure
midpoint synchrony or underwater stereo point accuracy. FishSizing
manual body-length ground truth can assess size prediction error,
not true 3D fish-centroid coordinate error.
