# Import explicitly exported YOLO/Ultralytics long-format tracks

Import explicitly exported YOLO/Ultralytics long-format tracks

## Usage

``` r
aqt_import_yolo(path, session_id, camera_id, fps = NULL, frame_origin = 0)
```

## Arguments

- path:

  CSV path with track_id or fish_id, x_px and y_px.

- session_id:

  Session identifier.

- camera_id:

  Camera identifier.

- fps:

  FPS if time_s is absent and frame is present.

- frame_origin:

  Index representing zero seconds.
