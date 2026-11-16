# Animal–Computer Interaction workflows

## Animal–Computer Interaction (ACI)

ACI research asks how an animal’s actions may be sensed, interpreted and
responded to through computing systems. Here the package provides
**measurement and audit utilities**, not independent evidence of animal
agency, preference or welfare.

![Schematic animal–computer feedback loop from observed fish action
through controller gate and actuator telemetry to review.](../aci.svg)

Conceptual only. The illustrated control loop must not be interpreted as
an independently certified live hardware safety system.

### Event and latency telemetry

The ACI functions help audit external time-stamped data across
behaviour, detection, command, actuator and response events.

- [`aqt_aci_trials()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_aci_trials.md):
  declared interaction trials.
- [`aqt_aci_loop_metrics()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_aci_loop_metrics.md):
  completeness and correctness of observed interaction loops.
- [`aqt_aci_latency_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_aci_latency_summary.md):
  reaction and device/loop latencies.

Distinguish detected false triggers, missing actuator acknowledgements
and true observed response. Event timing must be validated externally.

### Choice and access

- [`aqt_aci_choice_log()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_aci_choice_log.md):
  choices and **actual options offered**.
- [`aqt_aci_choice_summary()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_aci_choice_summary.md):
  descriptive option selection patterns.
- [`aqt_aci_access_inequality()`](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_aci_access_inequality.md):
  account for unequal access to real multi-option choice opportunities.

Choice frequency does not prove an animal’s conscious preference or
welfare benefit.

### From simulation to responsible experiments

Use the existing local/offline software dry-run and logging protocols
for engineering research. Any physical controller needs its **own**
ethics, operator approval, emergency-stop verification, failure
containment and biological review.

A static GitHub Pages site cannot actuate physical equipment. No remote
live-device control interface is included here.

**Read:** [source
protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/docs/ACI_CLOSED_LOOP_TELEMETRY.md),
[source
protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/docs/ACI_CHOICE_AND_ACCESS.md)
and [source
protocol](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/docs/ACI_PHYSICAL_DEVICE_PROTOCOL.md).
