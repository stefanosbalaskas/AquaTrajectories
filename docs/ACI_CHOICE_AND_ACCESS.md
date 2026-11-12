# Wave 10A extension — animal choice opportunity versus exercised choice

## Fundamental measurement distinction

A fish cannot exercise an option unless that option was physically
available. A detector activation also does not establish that the animal
made a choice. AquaTrajectories therefore keeps three constructs separate:

1. **Offered option**: an alternative was actually available to a fish.
2. **Exercised selection**: independently observed fish selection of
   one available option during the documented opportunity window.
3. **Device contingency**: separate closed-loop trial stages and
   physical actuator outcomes, measured by the Wave 10A telemetry
   module.

No universal animal "agency score" is produced. An observed action
cannot establish positive welfare, preference stability or understanding.

## Functions

- \`aqt_aci_choice_log()\`: one row per fish x trial x candidate
  option. Requires explicit offered/selected flags, a trial window,
  and an independently annotated selection time. Rejects a choice
  of an unoffered option, simultaneous multiple selections,
  missing offered alternatives, duplicate option rows and
  inconsistent per-fish trial/tank scope. A non-selection is valid.
- \`aqt_aci_choice_summary()\`: separates the number of opportunities,
  opportunities with >=2 genuinely available alternatives,
  any selection, actual selection under >=2 alternatives, per-option
  exposure and conditional selection frequencies, and observed
  choice latency. Does not infer preference from an option
  with zero or unequal exposure.
- \`aqt_aci_access_inequality()\`: computes an observed Gini of
  opportunity-normalized multi-option exercise rates across fish
  within the same tank/session, with a flag indicating whether
  exposure counts are balanced. Requires >=2 fish, each having
  at least one real multi-option opportunity. If no animal
  exercises a choice, Gini is NA rather than artificial equality.

## Example with explicit option sets

~~~r
library(aquaTrajectories)
log <- data.frame(
  session_id="S",tank_id="T",fish_id="F",
  trial_id=c("r1","r1","r2","r2"),
  option_id=c("shade","light","shade","light"),
  trial_s=c(0,0,10,10),
  trial_end_s=c(5,5,15,15),
  offered=c(TRUE,TRUE,TRUE,TRUE),
  selected=c(TRUE,FALSE,FALSE,FALSE),
  choice_s=c(1,NA,NA,NA)
)
verified_structure <- aqt_aci_choice_log(log)
report <- aqt_aci_choice_summary(verified_structure)
print(report$per_fish)
print(report$per_option)
# Requires additional fish in this tank for between-fish inequality:
# aqt_aci_access_inequality(verified_structure)
~~~

## Methodological boundaries

- The offered options must be physically accessible to that animal
  at the stated time; experimental apparatus logs and video
  annotations must substantiate them.
- The absence of a selection is not evidence of choice avoidance
  or lack of agency; an animal may be unable, unwilling or
  temporarily unmotivated to respond.
- Preference is not established by a single selected alternative.
  Repeated choice opportunities and balanced/re-randomized option
  presentation are needed to assess preference stability.
- Access inequality can reflect physical opportunity imbalance,
  visual occlusion, device interference, dominance or tracking
  error. The Gini is DESCRIPTIVE, not a diagnosis.
- Choice opportunity counts and fish exposures are NOT independent
  randomized treatment tanks; comparisons must respect
  experimental hierarchy and repeated observations.
- These descriptive analyses are separate from fish-device
  detection/command/actuator latency; there is no automatic
  causal link between a choice and a physical device response.
- This first version handles at most one selected alternative per
  fish opportunity; repeated/multi-selection interfaces require
  a different event-level data model.
- True biological preference, agency and welfare require
  defensible ethological theory and external experimental
  validation, not solely software scores.
