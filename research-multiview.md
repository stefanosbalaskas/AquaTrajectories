# Review two videos, one research timeline

Phase 3 · Research laboratory · transparent evidence boundaries

# Review two videos, one research timeline

Choose video files and CSV exports from your computer; none are
uploaded. The viewer uses an **explicit source frame manifest** to map
each selected research timestamp to the nearest original video
presentation timestamp. This is a data-review tool, not a system for
proving shutter synchronization.

## 1. Load a demonstrative scene or your own original sources

Open synthetic two-camera example

Clear local files and data

Frame manifest CSV Camera-local 2D tracks CSV (optional) Source-provided
XYZ tracks CSV (optional) Event table CSV (optional) Camera 1 local
video (optional) Camera 2 local video (optional)

Load selected CSVs and video files

Download frame schema example CSV

Required frame fields: session_id, camera_id, frame_id, time_s,
raw_time_s, width_px, height_px. The manifest must contain strictly
increasing aligned times and original PTS per camera. Optional tracks
use session_id, camera_id, track_id, time_s, x, y, observed (and z for
source-provided XYZ). Events use event_id, time_s, event_type. At most
10 MB per CSV is read locally.

No records loaded.

## 2. Synchronize by documented time mapping

Session

Maximum matched-time separation (s)

XYZ history window (s)

Research timeline

—

Previous recorded instant

Next recorded instant

Seek locally selected videos to PTS

### Camera A 

![](data:image/svg+xml;base64,PHN2ZyBpZD0ib3ZlcmxheUEiIHZpZXdib3g9IjAgMCA4MDAgNDUwIiByb2xlPSJpbWciIGFyaWEtbGFiZWw9IkNhbWVyYSBBIG1lYXN1cmVkIGNvb3JkaW5hdGUgb3ZlcmxheSI+PC9zdmc+)

### Camera B 

![](data:image/svg+xml;base64,PHN2ZyBpZD0ib3ZlcmxheUIiIHZpZXdib3g9IjAgMCA4MDAgNDUwIiByb2xlPSJpbWciIGFyaWEtbGFiZWw9IkNhbWVyYSBCIG1lYXN1cmVkIGNvb3JkaW5hdGUgb3ZlcmxheSI+PC9zdmc+)

A camera without a matched manifest frame shows an explicit gap. Video
seeking follows source raw_time_s rather than synthetic frame rates.
Actual HTML video decoding may seek to nearby frames; the viewer cannot
verify exposure-time alignment.

## 3. Source-provided XYZ and event alignment

![](data:image/svg+xml;base64,PHN2ZyBpZD0ieHl6U2NlbmUiIHZpZXdib3g9IjAgMCAxMDAwIDQ4MCIgcm9sZT0iaW1nIiBhcmlhLWxhYmVsPSJSb3RhdGVkIHByb2plY3Rpb24gb2YgdXBsb2FkZWQgc291cmNlIFhZWiBkYXRhIj48cmVjdCB4PSIwIiB5PSIwIiB3aWR0aD0iMTAwMCIgaGVpZ2h0PSI0ODAiIHJ4PSIxNCIgZmlsbD0iIzBiMjgzZCIgLz48ZyBpZD0ieHl6SXRlbXMiPjwvZz48L3N2Zz4=)

3D projection azimuth

25

3D projection elevation

20

A 3D point is displayed only when supplied in the source XYZ CSV (or
explicitly synthetic example). The viewer neither triangulates video nor
infers physical accuracy or cross-camera biological identity.

## 4. Keep the original evidence boundary

[Inspect local trajectory CSV
quality](https://stefanosbalaskas.github.io/AquaTrajectories/research-data-inspector.md)
· [Independent detection/ID/XYZ validation
guidance](https://stefanosbalaskas.github.io/AquaTrajectories/articles/validation-and-benchmarks.md)
· [Camera experiment
planner](https://stefanosbalaskas.github.io/AquaTrajectories/articles/plan-your-experiment.md)
