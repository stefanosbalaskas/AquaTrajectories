# Fish tracking, explored frame by frame.

Interactive teaching demonstration · synthetic data only

# Fish tracking, explored frame by frame.

Investigate a five-fish synthetic scene: compare two schematic cameras,
pause at an occlusion, inspect label switches, explore a logged event,
and export teaching data. Every path and metric is invented and has
arbitrary coordinate units; nothing comes from real fish video.

## Teaching lab controls

Choose a guided lesson 1 · Observe trajectories 2 · Missing fish
observations 3 · Track-ID confusion 4 · Compare camera projections 5 ·
Align an experimental event

Start with five invented paths. Choose an exercise to jump to a
meaningful frame.

Next lesson →

Projection Isometric 3D Top XY Side XZ Front YZ

3D orbit:

30°

Orbit changes the illustration, not camera calibration.

Visible simulated tracks

Inspect one simulated fish Fish F1 · Cyan Fish F2 · Amber Fish F3 ·
Lilac Fish F4 · Green Fish F5 · Rose

Research teaching toggles

Simulate a missing observation

Illustrate an ID switch after occlusion

For teaching only: missing points and swapped labels are invented, not
detector predictions.

Observation & camera layers

Draw schematic detector boxes

Show movement arrows

Compare top and side views

Mark a logged event Illustrative box jitter:

0 px

Boxes and jitter are drawn for teaching; no detection model is running.

Trail length:

60

frames Timeline:

0.0 s / 10.0 s

Logged event at 5.0 s · not causal evidence

−1 frame

▶ Play

+1 frame

↺

Playback speed 0.5× 1× 2×

Occlusion · 3.5s

ID switch · 4.3s

Event · 5.0s

300 equally spaced synthetic time steps at an illustrative 30
steps/second. This is not a video or hardware-synchronized recording.

**Isometric 3D projection**Paused · frame 0

![](data:image/svg+xml;base64,PHN2ZyBpZD0idGFuayIgdmlld2JveD0iMCAwIDk2MCA1NjAiIHJvbGU9ImltZyIgYXJpYS1sYWJlbGxlZGJ5PSJ0YW5rVGl0bGUgdGFua0Rlc2MiPjx0aXRsZSBpZD0idGFua1RpdGxlIj5TeW50aGV0aWMgZmlzaCB0cmFqZWN0b3JpZXMgaW4gYW4gYXF1YXJpdW08L3RpdGxlPgo8ZGVzYyBpZD0idGFua0Rlc2MiPkZpdmUgaW52ZW50ZWQgdHJhY2tzIHdpdGggc2VsZWN0YWJsZSAzRCwgWFksIFhaIGFuZCBZWiBwcm9qZWN0aW9ucy4gTm8gZW1waXJpY2FsIG9ic2VydmF0aW9ucy48L2Rlc2M+PGRlZnM+PGxpbmVhcmdyYWRpZW50IGlkPSJvY2VhbiIgeDI9IjAiIHkyPSIxIj48c3RvcCBzdG9wLWNvbG9yPSIjMTAyZDQ2Ij48L3N0b3A+PHN0b3Agb2Zmc2V0PSIxIiBzdG9wLWNvbG9yPSIjMDkyMzM4Ij48L3N0b3A+PC9saW5lYXJncmFkaWVudD48L2RlZnM+PHJlY3QgeD0iMCIgeT0iMCIgd2lkdGg9Ijk2MCIgaGVpZ2h0PSI1NjAiIHJ4PSIxOCIgZmlsbD0idXJsKCNvY2VhbikiIC8+PGcgaWQ9ImdyaWQiIGFyaWEtaGlkZGVuPSJ0cnVlIj48L2c+PGcgaWQ9InBhdGhzIj48L2c+PGcgaWQ9ImhlYWRzIj48L2c+PGcgaWQ9InRlYWNoaW5nT3ZlcmxheXMiIHBvaW50ZXItZXZlbnRzPSJub25lIj48L2c+PHRleHQgeD0iMjIiIHk9IjM4IiBmaWxsPSIjOGZjM2QxIiBmb250LWZhbWlseT0ic2Fucy1zZXJpZiIgZm9udC1zaXplPSIxOCI+U0lNVUxBVEVEIENPT1JESU5BVEVTIMK3IEFSQklUUkFSWSBVTklUUzwvdGV4dD48L3N2Zz4=)

Fish observations**5 / 5**at selected frame

Focus movement rate**—**arbitrary units / s

Nearest neighbor**—**3D arbitrary units

Event-relative time**−5.0 s**logged synthetic event

### Two simultaneous schematic views

Same invented 3D paths, no real cameras

Camera A · top XY

![](data:image/svg+xml;base64,PHN2ZyBpZD0iY2FtZXJhWFkiIHZpZXdib3g9IjAgMCA0MjAgMjUwIiByb2xlPSJpbWciIGFyaWEtbGFiZWw9IlN5bnRoZXRpYyB0b3AtdmlldyBmaXNoIHRyYWNrcyI+PC9zdmc+)

Camera B · side XZ

![](data:image/svg+xml;base64,PHN2ZyBpZD0iY2FtZXJhWFoiIHZpZXdib3g9IjAgMCA0MjAgMjUwIiByb2xlPSJpbWciIGFyaWEtbGFiZWw9IlN5bnRoZXRpYyBzaWRlLXZpZXcgZmlzaCB0cmFja3MiPjwvc3ZnPg==)

### F1 · computed movement

Frame-to-frame synthetic 3D displacement / s

![](data:image/svg+xml;base64,PHN2ZyBpZD0ic3BlZWRDaGFydCIgdmlld2JveD0iMCAwIDg0MCAxOTAiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iSWxsdXN0cmF0aXZlIHNlbGVjdGVkIGZpc2ggbW92ZW1lbnQgb3ZlciB0aW1lIHdpdGggZXZlbnQgbWFya2VyIj48L3N2Zz4=)

This plotted rate is mathematical displacement per simulated second, not
a calibrated swimming speed or welfare indicator.

Export teaching observations (CSV)

Save schematic scene (SVG)

Exports carry explicit **synthetic** labels; no uploaded recordings or
external services.

No teaching perturbations enabled.

CHECK YOUR INTERPRETATIONLesson 1 of 5

### Does viewing a simulated 3D scene establish measured underwater XYZ accuracy?

Yes

No

Choose an answer to see the explanation.

Keyboard: ← / → step by one frame, Space play or pause (when not editing
a control). Click a fish marker to inspect it.

**What you are seeing:** original deterministic curves and simplified
orthographic projections. Neither a real 3D reconstruction nor a
validated biological fish simulator. Turn on the occlusion toggle to
hide fish F1 for frames 90–125 without connecting missing segments;
enable ID switching to swap displayed labels F1/F2 after frame 125.
These labels are a deliberately invented diagnostic illustration, not a
tracker output. Real studies must supply physical camera calibration,
fish ID reference labels, actual timestamps and measured XYZ
uncertainty.

## Use the scientific software

[Real multiview and refraction
pipeline](https://stefanosbalaskas.github.io/AquaTrajectories/articles/multiview-3d.md)
[Conditional
uncertainty](https://stefanosbalaskas.github.io/AquaTrajectories/articles/uncertainty.md)
[Scientific evidence
limits](https://stefanosbalaskas.github.io/AquaTrajectories/articles/scientific-status.md)
[Detection, occlusion and ID switching
tutorial](https://stefanosbalaskas.github.io/AquaTrajectories/articles/identity-occlusion-tutorial.md)
