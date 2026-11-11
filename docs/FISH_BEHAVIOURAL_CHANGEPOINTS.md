# Wave 8A — descriptive aquatic animal behavioural change points

## Scope

AquaTrajectories provides a native R, exact dynamic-programming
implementation of a **piecewise-constant Gaussian squared-error
objective with a user-declared change penalty**, applied to one
camera/session-local fish behaviour series at a time. The model is
descriptive, not a hidden Markov model or an event-effect hypothesis
test. It does not label physiological stress or animal welfare.

## Functions

- \`aqt_state_changepoint(data,outcome,penalty,min_segment,max_gap_s)\`:
  globally minimizes sum of within-segment SSE plus a declared
  per-additional-segment penalty, with a minimum number of observations
  in every segment. Produces break indices, midpoint times, segment
  means, reconstructed fit and exact objective cost. Explicitly rejects
  missing values, duplicate timestamps, non-observed samples and
  timestamp gaps larger than the declared threshold.
- \`aqt_changepoint_event_delay(fit,events,max_delay_s)\`: reports the
  delay to the FIRST descriptive change after each externally logged
  intervention within a prespecified search window.
- \`aqt_plot_changepoints(fit)\`: displays observed behaviour values,
  fitted piecewise means and candidate transition times with base R.

## Minimal known-truth example

~~~r
library(aquaTrajectories)

fish <- data.frame(
  session_id="S01",camera_id="TOP",track_id="fish1",
  time_s=1:60,
  speed=c(rep(1,30),rep(3,30))
)
fit <- aqt_state_changepoint(
  fish,outcome="speed",penalty=10,
  min_segment=5,max_gap_s=2
)
stopifnot(fit$n_segments==2,
          fit$change_time_s==30.5)

feed <- data.frame(session_id="S01",event_id="feed",
  start_s=30,end_s=31)
aqt_changepoint_event_delay(fit,feed,max_delay_s=5)
aqt_plot_changepoints(fit)
~~~

The known-truth test does not imply observed real fish speed
transitions follow piecewise-constant Gaussian mean models.

## Statistical caveats

1. The penalty is an externally chosen squared-outcome cost, NOT an
   automatically calibrated Bayes factor, p-value or null test.
2. The loss weights each valid sample equally. Irregular sampling
   and missing frames can distort results; researchers should
   choose a biologically defensible sampling strategy and report it.
3. Change-point times are midpoints between consecutive observations,
   rather than exact physiological or controller response onset times.
4. Whole-trace camera errors and identity switches may themselves
   create spurious segmentation. Recompute under measurement-error
   scenarios before treating any transition as robust.
5. Sampling at 30-120 video FPS does not create 30-120 independent
   biological experimental units. Tank replication remains essential.
6. Event alignment shows temporal ordering; neither clustering of
   changes after feeding nor model fit establishes a causal effect.
7. This module does not implement a Hidden Markov Model, time-varying
   transition probabilities, animal choice, agency or measured welfare.
8. For very long traces, the O(n^2) dynamic programming method is
   capped at 1,500 valid samples. Pre-aggregation must be documented.

## Further qualification

- Simulated alternative state-transition structures, weak signals and
  biologically plausible duration distributions.
- Species- and camera-specific speed measurement-error benchmarks.
- False-positive rate, segmentation bias, and event-time detection
  accuracy under shadow/occlusion/identity-switch scenarios.
- Optional state models via independently qualified \`momentuHMM\`
  or other peer-reviewed R backends, without copying unqualified
  EyeTrajectories contracts.
