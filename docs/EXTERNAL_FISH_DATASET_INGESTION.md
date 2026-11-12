# Wave 11G — external fish dataset ingestion and independent scoring

This wave creates a *native annotation conversion*, not a pretrained fish
detector. It is designed for official Fraunhofer Sulawesi ricefish Datumaro and
MOT outputs once users acquire the actual downloads from:

https://cvg.hhi.fraunhofer.de/FishTracking.htm

**Important**: Fraunhofer footage uses a Basler a2A2448-75ucPRO industrial
camera (2448×2048) and a Ricoh 6 mm lens; it is NOT GoPro footage. Video A
has 101 independently labelled frames, 256 reported tracks and mean 91.2
fish per frame; B has 101 frames, 45 tracks and mean 19.5 fish per frame.
Those are publication/catalogue descriptors, not measured by this software.
The original downloads are not redistributed in the AquaTrajectories repo.

## Native Datumaro route

CVAT documents native Datumaro as:
- annotations/default.json containing categories.label.labels and items
- images/default/*, when the images are included
- bounding boxes [left,top,width,height], polygon points [x0,y0,...]
- temporally consistent tracking identity through attributes.track_id

Reference: https://docs.cvat.ai/docs/dataset_management/formats/format-datumaro/

Use the official archive after checking its original frame indices and image
dimensions. **Never infer timing from a basename or nominal FPS.** The origin
must be explicitly selected by examining one original image/annotation pair.

~~~sh
python inst/python/aqt_public_fish_adapters.py \
  --format datumaro --input /data/Fraunhofer_A_Datumaro.zip \
  --session-id FRAUNHOFER_A --camera-id BASLER_A \
  --source-frame-origin 0 --width 2448 --height 2048 \
  --output /results/fraunhofer_A_reference
~~~

If the actual file uses frame_000001 for its first acquisition, change
--source-frame-origin to 1 after source verification. Arbitrary image
IDs require an explicit mapping CSV with headers
item_id,source_frame_id and --frame-map /path/to/map.csv.

The exporter preserves source frame ID provenance, frames with no fish,
actual known tracked IDs only, and independent bounding-box coordinates.
It collapses bbox/polygon representations with an identical explicit
track or object-group identifier but does not fabricate identities when
Datumaro track_id is absent. Unsupported mask-only objects, ignored regions
or outside flags create review issues. All reviewed frames start with
annotation_status=published_annotation_unreviewed rather than falsely
being marked independently verified.

## MOTChallenge ground truth route

MOT ground truth is NOT tracker output. Its seventh field is an inclusion
flag, not detection confidence; its eighth field is a class and ninth
visibility. 1-based source frames become 0-based canonical IDs. An
explicit seqinfo.ini supplies the *complete* number of acquired frames,
including empty ones. The nominal frameRate in seqinfo.ini is not
accepted as a measured physical timestamp.

Reference: https://docs.cvat.ai/docs/dataset_management/formats/format-mot/

~~~sh
python inst/python/aqt_public_fish_adapters.py \
  --format mot --input /data/A/gt/gt.txt \
  --seqinfo /data/A/seqinfo.ini \
  --session-id FRAUNHOFER_A --camera-id BASLER_A \
  --output /results/fraunhofer_A_mot_reference
~~~

If seqinfo.ini is not included with a download, construct it ONLY from
verified original video dimensions/frame count. Keep a provenance record.

## Output contract and scientific gate

Every invocation outputs a single new directory, refuses overwriting an
existing nonempty directory and writes:
- frames.csv with camera/session, 0-based frame ID, width/height, source
  image ID and annotation_status
- boxes.csv with native *reference* fish boxes and class IDs
- tracks.csv with explicit native fish identity labels only
- issues.csv with unsupported/ignored annotation objects
- audit.json with source/output SHA-256, counts and false qualification
  flags for source review, physical timestamps and absolute XYZ accuracy

Do NOT feed these data directly into a verified 3D/stress conclusion.
The reviewer must reconcile ignored areas, prove source-to-video frame
correspondence and record that all reported frames were fully annotated,
including empty frames, before setting status fully_annotated and using
aqt_video_bundle_benchmark(). For biological MOT accuracy, additionally
calculate official TrackEval HOTA on the original split, not a proxy metric.

## Companion validation targets

- Official GoPro GPMF MP4s are for file/clock compatibility, not fish data.
- SFISHTRACK uses real underwater GoPro HERO3/HERO7 imagery with COCO
  segmentation and persistent fish tracks. It is the *real GoPro fish*
  domain-adaptation target after download:
  https://github.com/JosepSanchezCano/SFISHTRACK
- FishSizing includes ROS stereo calibration YAML and measured fish lengths:
  https://zenodo.org/records/19408363
  Its manual total lengths are NOT independently surveyed fish XYZ or
  evidence of live locomotion in its post-mortem Dataset A.

Independent real underwater XYZ calibration remains a field metrology gate.
