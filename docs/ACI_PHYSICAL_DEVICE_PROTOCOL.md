# Wave 15D — opt-in physical ACI device interface and fail-closed controller

AquaTrajectories now has a device-control **software interface** in
`inst/python/aqt_aci_physical_controller.py`. It is **not a real
hardware safety certification**, fish-welfare study, pre-existing
off-the-shelf firmware integration or permission to run an animal
experiment. Any actual fish device must be designed and independently
reviewed for the target species, system and institution.

## Hardware bridge protocol AQT1

The optional Python `pyserial` dependency is loaded **only** when
an operator explicitly requests `--mode hardware`. This mode
also **requires** both a physical USB serial port and
`--arm-hardware`. Default mode is **simulation**, which cannot
instantiate a real serial device and has no physical output.

An *independently implemented, verified* microcontroller must expose
newline-terminated UTF-8 JSON messages, each carrying
`"protocol":"AQT1"`. Firmware must implement:

- `{"op":"status"}`: reply with
  `protocol=AQT1`, device ID, firmware SHA-256,
  actual **hardware** `estop_engaged`, `hard_interlock_closed`,
  `watchdog_enabled` and `welfare_interlock_clear`.
  Every key must be a real firmware/hardware status. The Python
  application refuses absent, malformed or insufficient values.
- `{"op":"off"}`: guarantee output deenergization, reply
  `{"protocol":"AQT1","status":"off"}`. A USB software call is
  NOT a substitute for an independent normally-closed hard-wired
  emergency-stop relay/circuit.
- `{"op":"actuate","channel":"light",
  "duration_ms":100,"intensity_permille":100,"nonce":"..."}`:
  independent firmware must enforce pulse limits, device-specific
  welfare limits, electrical isolation, independent watchdog and
  normally-closed physical interlock. Reply
  `{"protocol":"AQT1","status":"accepted","nonce":"..."}`
  **only on actual accepted actuation**.
- `{"op":"feedback","nonce":"..."}`: report
  `{"protocol":"AQT1","status":"completed","nonce":"..."}`
  only after device-specific, **physically sensed** actuation
  completion; if the firmware cannot observe output state, it must
  not claim measured completion. The software conservatively labels
  even received feedback as DEVICE_REPORTED, not independent survey.

No hardware-compatible firmware or driver hardware is supplied in
this milestone. The code is a real programmable serial bridge, but
a connected microcontroller needs its own independently verified
firmware, stop circuitry and acceptance test before any animal use.

## Decision safety and audit

`ACIController` refuses commands unless:
- an original operator-specific, session-specific, tank-specific
  safety profile exists, with original firmware, ethics approval,
  independent E-stop test and watchdog test record SHA256s.
  Those self-reported hashes **do not independently verify**
  physical approvals; human checking is still required.
- a source event is a new unique original
  `aci_choice_request`, from the allowed tank/session, within
  a small measured host-monotonic event-age threshold, with
  externally declared valid fish detection and fish identity
  and sufficient confidence;
- channel is approved; per-pulse duration and intensity, minimum
  five-second cooldown, whole-session command count, accumulated
  active duration and per-minute command count remain within
  external profile limits and absolute software hard bounds;
- the firmware reports a *physical* released E-stop, closed
  hard interlock, enabled watchdog, clear welfare interlock,
  exact expected device and firmware SHA, and acknowledges safe OFF.
- the fresh hardware command gets a matching nonce acknowledgement,
  actual device-reported completion, and a verified safe OFF.
  Missing/stale/unmatched actuator feedback, wrong firmware or
  an unavailable E-stop **latches emergency stop**, refuses
  rearming until a new controller session, and attempts to
  deenergize hardware. Safety hardware must independently cut
  power even if the Python process, OS or serial line fails.

Hardware event source must be **live stdin JSONL** generated
on the same host-monotonic time base, not a copied old experimental
CSV or a remotely assumed timecode. Offline replay with a virtual
monotonic clock is allowed only in simulation mode.

The controller persists original event/decision/command/
feedback telemetry; all independently unauthenticated biological
and physical-approval flags remain FALSE, including when a
real serial device acknowledges activity.

## Example simulation-only workflow

Create an external safety-profile JSON with schema
`aqt_aci_safety_profile_v1` and exact keys:

`session_id,tank_id,device_id,operator_id,firmware_sha256,
physical_estop_test_record_sha256,ethics_approval_record_sha256,
hardware_watchdog_test_record_sha256,approved_protocol_reference,
allowed_channels,cooldown_s,max_session_commands,
max_pulse_duration_ms,max_intensity_permille,max_total_active_ms,
max_feedback_wait_s,max_source_event_age_s,min_source_confidence`.

Example safe hard limits: cooldown >=5 seconds, pulse
<=1000 ms, intensity <=500 per mille, total active
<=5000 ms, no more than 20 commands per entire session.
**These hard ceilings are not scientifically proven safe for
any fish species.** The external approved profile must set
more conservative species/tank-specific exposure limits.

Replay event JSONL rows contain `event_id,event_type,
session_id,tank_id,observed_at_monotonic_s,validated_identity,
validated_detection,confidence,channel,duration_ms,
intensity_permille`. Use synthesized fixture data to test
software first; never mark model identity independently
validated without original blinded annotations.

```bash
python inst/python/aqt_aci_physical_controller.py \
  --profile /external/approved_research_profile.json \
  --mode simulation --operator-id RESEARCHER1 \
  --events-jsonl /data/simulated_events.jsonl \
  --out /data/logs/aci_dry_run.json
```

An actual approved hardware activation *would* require
`--mode hardware --arm-hardware --device-port <serial-port>`
and real-time JSONL from stdin. This repository/CI has **never
made such a physical activation**.

## Remaining actual hardware experimental closure

1. Design and independently bench-verify AQT1 compatible microcontroller
   firmware; check independent hardware watchdog timeout, stuck-ON
   output fault and physical stop that works with the host turned off.
2. Test the real E-stop and waterproof electrical safety with the
   device disconnected from any living animals.
3. Obtain ethics/welfare approval and empirically determine
   appropriate species/device physical limits.
4. Run documented laboratory device latency, false positives and
   feedback tests on the actual experimental tank, with no
   software-reported actuator acknowledgement substituted for
   independent output observation.
5. Only then run ethics-approved replicated animal trials with
   externally reviewed source behaviour, stress and welfare labels.

No original animal or physical hardware results are represented
by the simulation fixtures. Scientific issue #51 remains OPEN.
