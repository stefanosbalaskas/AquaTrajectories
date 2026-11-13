# Wave 15C — unified local multiview 2D/3D/uncertainty/ACI research explorer

The prior `inst/explorer/index.html` is a one-video research
preview. New `inst/explorer/multiview.html` is a **read-only
multi-camera research console** designed around the outputs of the
new automated stereo ingestion pipeline.

## Actual supported interface

- Load full *original* frame-clock CSV, camera-local 2D fish trajectories,
  3D reconstructed XYZ fish positions, provisional cross-camera link table,
  original intervention-event log, and optional empirically calibrated
  joint uncertainty JSON from user-selected local files. No uploads.
- Browse all cameras present in the original source trajectories.
  Select the matching original video manually for each camera; the
  application does not falsely assume that every camera video is a
  matching file or that all cameras have identical frame rates.
- One **world-time** research slider maps to exact, nearest declared
  original video presentation timestamps for each camera with
  **configurable maximum skew**. Frames outside tolerance display
  an explicit absence rather than interpolating. Play original media,
  pause, select a clock-master camera and review video-local vs
  externally aligned clock offsets.
- Interactive projected 3D fish trajectories with zoom-compatible
  spatial scale, yaw/pitch sliders, independently retained source
  3D coordinates, missing-data/gap segmentation, fish identity colors,
  and frame-level candidate visualizations.
- Show source original event labels within the declared window, mark
  arbitrary local notes at the selected synchronized time and export
  reviewer annotations **as local JSON**. No local draft notes are
  treated as validated biological annotations without review.
- Optionally draw uncertainty spheres from an empirical source
  calibration report; declare whether external physical-survey and
  fish-ID labels were independently checked. Missing/no-finite
  empirical interval remains explicitly missing, not a fabricated
  95% confidence region.
- All UI elements have labels/controls, DOM data are written using
  `textContent` to avoid HTML injection from untrusted original
  video/annotation text, and actual devices are **never contacted**.

The first explorer remains accessible at `index.html`; its new
link opens the unified multiview interface.

## Source file layouts

The new pipeline's native R runner exports:

```text
source_frames.csv          session_id,camera_id,frame_id,time_s,raw_time_s,width_px,height_px
source_2d_tracks.csv       session_id,camera_id,track_id,time_s,x,y,...,observed
fish_3d_tracks.csv         session_id,camera_id,track_id,time_s,x,y,z,...,observed
crossview_links.csv        session_id,id_a,id_b,fish_id,...,camera_a,camera_b
stereo_audit.json          provenance, source scopes and scientific flags
```

The optional `events.csv` accepts `event_id,time_s,event_type`.
The optional empirical report has schema
`aqt_empirical_joint_fish_uncertainty_v1`.

## Run

```bash
python -m http.server 8765 --directory inst/explorer
```

Then open `http://localhost:8765/multiview.html` and
load source records and your original video files via the
file selectors.

## Claims forbidden

This is a complete **read-only interactive viewing software
implementation**, not evidence of user-validated usability,
camera exposure electrical synchronization, calibrated tank
3D accuracy, independently observed animal identities, welfare
or a certified physical ACI controller. The browser has no
hardware commands, no network uploads and no animal
intervention authority. External human usability/accessibility
research remains unperformed. Issue #51 stays open.

## Physically consistent uncertainty visualization contract

The original `stereo_audit.json` output is now a separate
optional local file selector. **It is required to visualize any
non-null empirical uncertainty radius**. The source includes
`source_3d_units` (`cm` or `m`), original 3D row counts and
explicit biological/physical scientific FALSE flags. The reader
checks the exact 3D CSV row count and rejects unexpected scientific
certifications or out-of-scope sources.

The uncertainty report from Wave15B must give the **same
original XYZ units** as the 3D source audit. If the units are
absent or differ, the viewer refuses the radius instead of
drawing misleading scales. Correct source-relative image pixels
are mapped into the contained video element with letterbox
offset compensation; this avoids shifted fish overlays when
original camera sensor aspect ratio differs from a 16:9 preview.

This is UI/data integrity and not actual independently
certified physical 3D calibration accuracy.
