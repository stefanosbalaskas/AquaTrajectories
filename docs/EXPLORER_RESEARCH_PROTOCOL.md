# Wave 13C — Portable local 2D/3D video researcher explorer

This is a **working front-end software-integration milestone**, not
physical measurement, biological validation, or an online service.

## Starting

From an AquaTrajectories repository checkout:

    python3 -m http.server 8765 --directory inst/explorer

Open http://127.0.0.1:8765/index.html in a browser.
The interface requires no external JavaScript packages, cookies, logins,
network storage, cloud model or automatic hardware control. All files
remain in the browser. Closing the page ends the local viewing session.

## Inputs and trustworthy scope

1. Optional **original local fish video**, loaded from a user-selected
   local file; playback uses the browser's video clock.
2. Canonical CSV created by `aqt_export_csv` or an equivalent
   independently validated export: session_id, camera_id, track_id,
   time_s, x, y, optional z and observed.
3. Actual decoded frame PTS CSV from the Python video runner/real
   Oxford video audit: session_id, camera_id, frame_id, time_s, width_px,
   height_px. **No FPS is inferred or used to manufacture timestamps.**
4. External intervention/event log with event_id, time_s, event_type.
   The events are on the same stated local timebase only if independently
   verified upstream; this interface **does not synchronize clocks**.
5. Optional reviewer **draft notes** entered at the selected local
   video time and exported as JSON with independent review set to false.

Frame and fish selection use a user-controlled time tolerance; if no
observation is within tolerance, the interface does **not** interpolate,
fill missing locations or assign identities. Track IDs are distinct
within (session_id,camera_id); cross-camera fish identity is never
silently equated. 2D pixel positions are overlaid only where the source
data are image coordinates, and only 3D source rows containing finite
XYZ are projected to an interactive tank scene. The 3D projection
does not reconstruct new physical points and is not uncertainty
calibration.

## Acceptance

Exact-source Node unit tests cover strict CSV and source PTS parsing,
required track scope, duplicate identity/time rejection, unknown fish
locations, 3D perspective projection, external events and
non-certification flags. A dedicated GitHub Actions job serves the
actual standalone package interface over local HTTP and validates
the browser module syntax. **Visual/browser interaction remains to
be independently tested**, including licensed video playback,
multiple-camera switching and screen-reader accessibility.

## Outstanding UI and ACI integration

- Multi-camera *simultaneous* playback and hardware exposure-offset
  validation need actual two-camera videos, markers and original
  calibration metadata. A drop-down camera selector is NOT hardware sync.
- Add reviewer-verified annotation ingestion and exact source hashes,
  undo/redo correction audit and versioned data export before claiming
  externally reviewed fish identities.
- Add joint uncertainty ribbons only when the uncertainty draws are
  calibrated or expressly labelled conditional scenario assumptions.
- Add actual device adapters only after approved animal research
  protocols, operator consent, emergency stop, treatment constraints,
  independent response logs and device-level testing.
- Complete official IDF1/HOTA and surveyed XYZ metrology separately.

Full roadmap acceptance:
https://github.com/stefanosbalaskas/AquaTrajectories/issues/51

## ACI safety-gated offline controller prototype

The browser interface now includes an **explicitly simulated**
animal–computer interaction event-plan panel. The pure function
`dryRunACI(events,options)` consumes only externally logged
`aci_choice_request` events and requires a nonempty external study
approval reference, virtual device name, maximum intensity/duration,
cooldown and maximum command count. Emergency-stop is **engaged by
default**; engaging it produces zero commands. It returns only
`execution_status: SIMULATED_ONLY` entries. There are **no physical
actuators, hardware network requests or animals controlled**.

CI tests check cooldown, maximum commands, emergency stop, missing
approval and invalid intensity. This is a dry-run architecture for
priority 8, **not** proof of adequate animal welfare constraints.
Real ACI controllers need actual approved protocols, independent
device emergency stop implementation, limits validated for the fish
species, fish-observed choice logs, device-level trials and
independently replicated tank designs. It would be inappropriate to
describe a local browser simulation as a deployed enrichment device.
