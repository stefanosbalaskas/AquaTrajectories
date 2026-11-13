# Wave 14J — original fish-tank hardware measurements required for scientific closure

AquaTrajectories now has working refractive 3D reconstruction, heldout
clock fitting, and holdout-target error calculations. What remains
before **independent scientific certification** is to bring authentic
experiments into those modules without inventing physical exposure
times, surveying measurements, biological fish identities or tank
replicates.

This protocol applies to a real research installation with
top/side cameras, GoPro, a machine-vision camera, or similar sources.

## 1. Collect two or more original camera source recordings

Mount two physical cameras so their full field-of-view overlaps at
fish swimming depths and the tank's reflective wall/port geometry is
documented. Do **not** treat a saved 25-fps transcoded MP4 as
evidence that a GoPro's shutter exposed at exactly 25 or 60 fps.

For each source camera, retain the ORIGINAL file and compute SHA-256.
Record original codec, nominal frame rate, width/height, genuine
video-local frame presentation times, and explicit source of *actual
exposure* timing. Video-local MP4 PTS is **not** globally synchronized
UTC/exposure timing. If cameras offer hardware exposure TTL or trigger
timestamps, preserve those separate physical logs; flashing an LED in
view is a useful approximate synchronization marker but not proof of
sub-frame shutter-exposure alignment.

Provide `videos.csv` with header:

`session_id,camera_id,video_path_relative,video_sha256,codec,width_px,height_px,nominal_fps,timestamp_origin,calibration_sha256`

`timestamp_origin` must be `video_local_pts`,
`hardware_exposure_pulse`, or `unknown`. Even the declared latter
type is self-reported and has not been independently authenticated.

## 2. Preserve independently corresponding camera exposure markers

Record a minimum of **6 independent physical marker events per
session and camera**, at least 4 to estimate offset/drift and at least
2 separately heldout events. The actual stimulus/TTL identifier needs
a unique external log reference common across the cameras, not simply
a matching filename. Retain camera-local raw timestamps.

Provide `pulses.csv` with header:

`session_id,camera_id,marker_id,time_s,measurement_type,external_pulse_reference`

Allowed measurement types: `hardware_exposure_pulse`,
`visual_flash`, `video_local_pts`. The latter two can
support exploratory alignment, **not hardware exposure certification**.
The new intake tool checks coverage, uniqueness, same documented
physical reference and increasing camera-local pulse time order.
The existing R `aqt_sync_holdout_fit()` then checks affine
clock-offset/drift residuals on the physically heldout events,
without certifying those events came from actual shutter hardware.

## 3. Obtain independently surveyed underwater 3D target coordinates

Record one or more real target trial assemblies at multiple
underwater depths and multiple positions in the two viewports.
Use a physically measured coordinate frame with explicit
units, glass thickness, refractive indices and independent camera
intrinsic/extrinsic calibration. A printed-board design specification
alone is **not** an independent physical survey of its submerged
installed target XYZ.

Each trial needs at least 6 fit targets and at least 3 heldout targets.
The fit and holdout board assemblies must be **different**, not two
subsets from one board. Both fit and holdout need depth variation.
For every independently surveyed target, record paired
*undistorted* pixel centroids observed in both real camera frames.
Keep the external survey certificate/file with its SHA-256.

Provide `targets.csv` with header:

`trial_id,tank_id,session_id,camera_a_id,camera_b_id,target_id,target_group,partition,truth_x,truth_y,truth_z,a_u_px,a_v_px,b_u_px,b_v_px,units,external_survey_record_sha256`

Partition is `fit` or `holdout`; units are `cm` or `m`.
Never derive the heldout XYZ truth from the same unvalidated 3D
reconstruction algorithm under test.

## 4. Record experimental interventions at the independent tank level

For fish welfare and ACI studies, retain the original event protocol,
fish observations, independent expert reference labels, site ethics
approval, genuine device response logs and emergency-stop outcomes.
Replicated **tanks**, not many frames or many fish from one tank,
are the independent treatment randomization units. Treatment
assignment needs preserved randomization records; the intake tool
does not prove their independence or ethics.

Provide `events.csv` with header:

`session_id,tank_id,event_id,event_time_s,treatment_arm,randomization_unit,randomization_record_sha256,device_id,ethics_protocol_reference`

For randomized treatment experiments, `randomization_unit`
must be `tank`. A header-only events file is permitted when the
project is still doing camera/XYZ calibration without animal
intervention. No physical ACI control is initiated by the intake.

## 5. Intake invocation and R handoff

The command uses only original externally measured CSVs. No source
videos or raw experimental observations are bundled with the
repository.

```bash
python inst/python/aqt_real_multiview_lab_intake.py \
  --videos /data/real/videos.csv \
  --pulses /data/real/pulses.csv \
  --targets /data/real/targets.csv \
  --events /data/real/events.csv \
  --training-pulses pulse_1,pulse_2,pulse_3,pulse_4 \
  --heldout-pulses pulse_5,pulse_6 \
  --video-root /data/real/raw_cameras \
  --out /data/audit/real_intake.json
```

`pulse_1`…`pulse_6` above are **illustrative IDs only**;
replace them with actually measured source event IDs.

If all source contracts pass, the tool generates three separate,
checksum-linked outputs:

- `real_intake.json` — provenance, source CSV SHA-256, original
  video byte hash status, mandatory caveats and qualification flags.
- `real_intake_R_markers.csv` — exact session/camera/marker/time
  columns for native R `aqt_sync_holdout_fit()`.
- `real_intake_R_targets.csv` — exact world XYZ and paired 2D
  target columns for native R `aqt_target_trial_table()`.

Then run on externally calibrated physical refractive camera models:

```r
markers <- read.csv("real_intake_R_markers.csv")
targets <- read.csv("real_intake_R_targets.csv")

audit <- aqt_multiview_holdout_protocol(
  markers = markers,
  surveyed_targets = targets,
  cameras = real_fitted_refractive_cameras,
  reference_camera = "TOP",
  train_markers = c("pulse_1", "pulse_2", "pulse_3", "pulse_4"),
  holdout_markers = c("pulse_5", "pulse_6"),
  max_holdout_error_s = 0.005,
  target_units = "cm"
)
```

The `real_fitted_refractive_cameras` input must be supplied from
actual external calibration data. `0.005` seconds is only an example
tolerance; specify the real allowed sync error before viewing
holdout residuals. None of the example parameters are asserted to
be values from a completed fish-tank study.

## Scientific acceptance beyond the software contract

- Verify source videos can be **decoded**, source frame PTS correspond
  to actual camera exposures, and physical marker logs are authentic.
- Validate the true underwater XYZ target survey against calibrated
  measurements independent of the algorithm being evaluated.
- Fit camera/refraction models on disjoint fit data and benchmark
  **AquaTrajectories itself** against heldout real target XYZ with
  error per axis, bias, RMSE, invalid reconstruction rates and
  empirically calibrated uncertainty coverage.
- Independently label actual fish identities across viewports and
  compare source video-based detections/tracks with reference, not
  oracle fish location inputs.
- For behavioural welfare or ACI, complete ethics approval, actual
  instrumented animal trials, real emergency-stop hardware tests,
  blinded biological annotations, and independently randomized/
  replicated experimental tanks.

Passing the intake script or its synthetic software tests is not
evidence that any of these external experiments have been performed.
Keep [scientific gate #51](https://github.com/stefanosbalaskas/AquaTrajectories/issues/51)
open until independent source material and results exist.
