# Wave 6B — discrete fish-identity scenarios and statistical sensitivity

## Why not simply add noise to coordinates?

An ID switch is a discrete error that can reassign a WHOLE suffix
of an observed fish trajectory to a different tracked fish. Independent
Gaussian position jitter cannot represent the induced sudden jump in
swimming speed, change in path length or reallocation of event response.

This module therefore represents an explicit set of proposed ID-swap
events with externally supplied hypothetical probabilities, then
propagates entire coherent identity assignments through the same
kinematic and tank-level analysis pipeline as other data.

## Native functions

- aqt_identity_switch_scenarios(): validate scoped IDs, event times and
  hypothetical probabilities. Samples one decision per proposed ID
  crossing event and scenario; preserves R's outside RNG state.
- aqt_identity_draw(): permute labels from crossing time forward while
  preserving original source IDs and an assignment_changed flag.
- aqt_identity_path_sensitivity(): recalculate path length and swimming
  speed from each WHOLE trajectory assignment.
- aqt_identity_event_sensitivity(): recalculate kinematics and before/after
  event windows without independent frame-level identity draws.
- aqt_identity_tank_sensitivity(): estimate independent-tank pre/post
  treatment-group contrasts separately under each identity scenario,
  with a distinct within-scenario bootstrap across tanks.

## Known-truth demonstration

~~~r
library(aquaTrajectories)

raw <- aqt_tracks(data.frame(
  session_id="S",camera_id="TOP",
  track_id=rep(c("A","B"),each=7),
  time_s=rep(0:6,2),
  x=c(0,1,2,13,14,15,16,10,11,12,3,4,5,6),y=0
),units="cm",coordinate_system="tank")

candidate <- data.frame(
  session_id="S",camera_id="TOP",
  track_a="A",track_b="B",
  at_s=3,probability_swap=.5
)
scenarios <- aqt_identity_switch_scenarios(
  raw,candidate,draws=100,seed=11
)
corrected_example <- aqt_identity_draw(scenarios,draw=1)
results <- aqt_identity_path_sensitivity(scenarios,max_gap_s=1)

events <- data.frame(session_id="S",event_id="feed",
                     start_s=3,end_s=3)
responses <- aqt_identity_event_sensitivity(
  scenarios,events,outcome="speed",
  windows=list(baseline=c(-3,0),response=c(0,3))
)
~~~

Here the original labels exchange physical fish at t=3. If a
particular scenario assumes a true identity switch, the software
relabels ALL observations after the crossing, not individual frames.

## Limitations and scientific qualifiers

1. The supplied probability_swap values are NOT estimated, certified or
   validated by AquaTrajectories. They represent independent annotation
   evidence or sensitivity assumptions defined by the researcher.
2. The proposed label exchanges are within ONE session/camera only.
   Cross-camera permanent reidentification is NOT solved.
3. Only pairwise future-suffix swaps are currently represented; identity
   disappearance, multiple-hypothesis tracking probabilities, complex
   group permutations and uncertain swap timestamps remain open.
4. Candidate track pairs cannot cross tanks when tank_id is supplied.
5. Multiple switches are applied in event order to current assigned
   track labels. The order matters: document the assumed event sequence.
6. Within-scenario bootstrap resampling of independent tanks is
   conceptually different from across-scenario measurement sensitivity.
   The module returns them separately and does NOT construct a
   validated joint uncertainty interval or causal estimand.
7. Reconstructed 3D positions still require valid camera calibration and
   refraction modelling. Assigning fish identities cannot repair
   an uncalibrated optical system.
8. Real annotated multi-fish crossings and calibration studies must test
   event-probability accuracy, coverage and effects of incorrect timing.
9. Biological stress, welfare, attraction and leadership cannot be
   established from identity-sensitivity outputs alone.

## Next research gate

Link alternative identity assignments with camera calibration and temporal
synchronization scenarios, then evaluate model coverage and tank-level
inferential stability on independent benchmark video and known-event
aquaculture experiments.
