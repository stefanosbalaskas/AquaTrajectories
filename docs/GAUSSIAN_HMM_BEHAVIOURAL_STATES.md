# Wave 8D: conditional Gaussian Hidden Markov models for observed fish behaviour

## Purpose and exact interpretation

Fish movement outcomes such as speed or acceleration may alternate among
descriptively different regimes. AquaTrajectories now offers a bounded
**univariate Gaussian HMM** that decodes a fish's observed outcome under
an **externally specified** emission model and transition probabilities.

The method uses standard log-domain forward-backward and Viterbi recursions.
It does not learn the state means, standard deviations or transitions,
and it does not infer whether any state represents stress or fish welfare.
State labels such as "slow" and "fast" are user-defined descriptions,
not validated biological categories.

## Canonical input

A long data.frame must contain session_id, camera_id, track_id, time_s,
and one numeric outcome (default speed). Optional tank_id, treatment and
observed flags are retained. The track ID is scoped to session/camera
and, when supplied, tank; it is not inferred to be permanent biological
identity across cameras. Every continuous observed fish run is decoded
**separately**. Missing outcomes, observed=FALSE, gaps exceeding
max_gap_s, and new fish/camera/session/tank IDs prevent artificial
Markov transitions. A segment shorter than min_segment remains explicitly
unclassified. Unknown outcome values are not interpolated or imputed.

## Example

~~~r
library(aquaTrajectories)

fish <- data.frame(
  session_id="S1",camera_id="TOP",track_id="F1",tank_id="T1",
  treatment="control",time_s=seq(0,1.9,by=.1),
  speed=c(rep(.5,10),rep(3,10))
)
T <- matrix(c(.95,.05,.05,.95),2,2,byrow=TRUE)
decoded <- aqt_hmm_decode(
  fish,outcome="speed",
  state_means=c(.5,3),state_sds=c(.3,.3),
  transition=T,initial=c(.5,.5),
  state_labels=c("slow","fast"),max_gap_s=.11,min_segment=3)
print(decoded[,c("time_s","hmm_usable","hmm_segment",
                 "hmm_state_label","hmm_p1","hmm_p2")])
print(aqt_hmm_state_summary(decoded))
attr(decoded,"aqt_hmm_segment_loglik")
~~~

## Mathematical contract

For each fish segment, the emission probability is a Gaussian density
p(y_t | state_t=k) with supplied state means and SDs.
T[i,j] denotes Pr(state_(t+1)=j | state_t=i), rows summing to one.
The first-sample distribution defaults to uniform, or is supplied as
initial. Recurrences operate on log probabilities using log-sum-exp.
Posterior probabilities are normalized at each time, and a separately
computed Viterbi path is returned.

The transition matrix represents **one observed sample step**.
A declared max_gap_s prevents invalidly long transitions, but sampling
intervals within that limit may still vary. The HMM does not estimate
a continuous-time transition rate, irregular-time transition powers,
session-specific effects, or calibration/identity uncertainty.

The output contains hmm_state (Viterbi integer), hmm_state_label,
hmm_entropy, hmm_p1..hmm_pK, hmm_usable, hmm_value and hmm_segment.
Posterior and labels are NA when the sample is missing or unsupported.
Segment log likelihood is conditional on exactly the specified model.
The supplied means must be strictly increasing, fixing label order.

## Scientific cautions and future validation

1. Manually chosen Gaussian emissions are assumptions, not biological
   ground truth; overlapping distributions can yield unstable labels.
2. Time-varying conditions, animal-level random effects and unequal
   sampling intervals are not estimated by this decoder.
3. Fish-state sample fractions are descriptive. An experiment assigning
   interventions to tanks must aggregate/estimate at the tank level.
4. Potential tracking-ID swaps, missed detections and uncertain underwater
   XYZ affect speeds and any resulting state classification.
5. Evaluate observational test-retest reliability and sensitivity to
   state count, emission parameters, tracking quality and recording rate.
6. Compare decoded states against independently annotated behaviour.
   Do not call them stress, pain, distress or welfare without external
   biological evidence.

## Next stage

Add qualified parameter fitting with multi-start optimization,
heldout sequence likelihood, posterior predictive checking and
experiment-level replication. Any learned-state model will require
nonidentifiability/label-switch and numerical-degeneracy diagnostics.
