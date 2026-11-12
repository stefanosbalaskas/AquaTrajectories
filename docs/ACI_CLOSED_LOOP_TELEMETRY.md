# Wave 10A — Animal–Computer Interaction closed-loop telemetry

## What this module measures

A controlled animal–computer interaction experiment may provide
opportunities for a fish to activate a device, trigger an environment
change, or request an enrichment object through movement.

AquaTrajectories evaluates the event chain:

1. An externally logged opportunity was available.
2. A fish action was independently observed or annotated.
3. The sensor/detector detected the action.
4. The computer/control system commanded the device.
5. The physical actuator event was independently confirmed.
6. Optionally, an observed subsequent fish response was logged.

These are **separate observations**, not interchangeable timestamps.
The code will not substitute a detector trigger as proof of genuine
fish action, or a computer command as proof of physical actuation.

## New public functions

- \`aqt_aci_trials()\` validates session-scoped opportunities and
  optional fish action, detection, command, actuator and response
  times on a synchronized clock. All stage transitions must be
  physically time-ordered within a declared trial window.
  An unannotated action with a detector event is retained as a
  *candidate false trigger*, conditional on the reference
  annotation being correct.
- \`aqt_aci_loop_metrics()\` summarizes the number of opportunities,
  observed actions, missed detections, false triggers, true and
  false physical activations. When both action and no-action
  opportunities are represented, it reports:

  \`P(physical actuation | fish action) -
    P(physical actuation | no annotated fish action)\`

  This is a **descriptive contingency contrast**, NOT a direct
  causal or behavioural agency estimator.
- \`aqt_aci_latency_summary()\` separately reports the median
  detection latency, command latency, command-to-actuator latency,
  end-to-end action-to-physical-actuator latency, and the number of
  fully observed loops. Missing stages do not receive zero latency.

## Minimal trial log

~~~r
library(aquaTrajectories)

trial_log <- data.frame(
  session_id="S1",trial_id=c("r1","r2","r3"),
  fish_id="F1",
  opportunity_s=c(0,10,20),
  end_s=c(5,15,25),
  action_s=c(1,11,NA),
  detection_s=c(1.1,NA,21),
  command_s=c(1.2,NA,21.1),
  actuator_s=c(1.4,NA,21.3),
  response_s=c(1.8,NA,21.8)
)
verified_structure <- aqt_aci_trials(trial_log)
aqt_aci_loop_metrics(verified_structure)
aqt_aci_latency_summary(verified_structure)
~~~

In this example the third trial has no independently annotated
fish action but does have detector/actuator activity. It must
not count as successful fish-triggered control.

## Interpretation and safeguards

- The reference animal behaviour annotations must be independently
  audited. Without this, computed false-trigger rates may themselves
  be false. \`annotation_certified\` remains FALSE by default.
- Both fish and device timestamps must be aligned with a traceable
  recording clock. Timestamp ordering alone is NOT clock
  synchronization validation.
- One row is one externally defined opportunity and one fish.
  Repeated/simultaneous opportunities require explicit,
  non-overlapping trial attribution, not arbitrary video-frame joins.
- A fish that never acts is not necessarily refusing an option;
  physical access, motivation and experimental context matter.
- High response contingency does not establish animal understanding,
  agency, learning, preference, autonomy or positive welfare.
- Treatment comparisons require independently replicated tank
  assignment and appropriate multilevel statistical models.
  Fish opportunities and event logs are not automatically
  independent experimental tanks.
- Learning and preference development require a longitudinal design
  with repeated choice opportunities, experimental controls, and
  preferably yoked or contingent-versus-noncontingent conditions.
- Hardware/controller processing delays can confound apparent
  fish response latency.
- This first module does not reconstruct fish actions directly
  from video or validate a physical device.

## Next ACI research stage

Implement explicit *offered options* and *exercised choices*
with device-access inequalities among fish, opportunity visibility,
independently calibrated detection reliability, preference stability
and animal-specific temporal learning models. All these should
remain distinct from physical controller performance and welfare.
