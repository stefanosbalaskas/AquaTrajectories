# Wave 8G — event-aligned probabilistic fish states and independent tanks

## Objective

This bridge joins externally verified event timestamps (feeding,
enrichment, aquaculture interventions and ACI device actions) with
Wave 8D/8E fish HMM posterior state probabilities, without treating
video frames or multiple fish in one tank as independent treatment units.

The function **does not** infer fish preference, stress, distress,
welfare, a feeding effect, physiological latency, or treatment causality
by itself.

## Workflow

~~~r
library(aquaTrajectories)
# decoded: result of aqt_hmm_decode() on synchronized per-fish speed;
# includes tank_id, treatment and session_id.
# events: aqt_event_table-compatible start/end times per session.
epoch_tanks <- aqt_hmm_event_tank_epochs(
  decoded,events,state=2L,
  baseline_window_s=c(-30,0),
  response_window_s=c(0,30),min_points=4L,
  treatment_levels=c("control","treatment"))
print(epoch_tanks)
fish_support <- attr(epoch_tanks,"aqt_hmm_fish_epochs")
print(fish_support)
result <- aqt_hmm_tank_event_contrast(
  epoch_tanks,treatment_levels=c("control","treatment"),
  draws=999L,level=.95,seed=23L)
print(result$estimate)
print(c(result$lower,result$upper))
print(result$per_tank)
~~~

## Observational and experimental units

For each recorded tank, one recording session and one externally
verified event onset are required. Each tank must provide **one**
camera-local view or an already reviewed/fused biological fish-track
view; multiple unreconciled camera views are rejected to avoid
silently counting the same fish more than once. The method rejects repeated-event
designs, multiple recording sessions per tank, treatment switching
and fewer than two independently allocated tanks in either arm.
These restrictions protect a bounded between-tank intervention
comparison; more complex studies require longitudinal hierarchical
models and valid design-specific estimands.

Every fish must have a fully supported baseline and response epoch.
Wave 8D posterior probability `hmm_pK` is averaged across supported
recorded observations within each fish/epoch. Missing/unsupported
observations remain excluded and are counted; no interpolation is
introduced. The same complete fish enter baseline and response,
which prevents systematic composition switching across epochs.

Next, all eligible fish within each tank contribute **equally**
to each tank epoch. A tank is then ONE independent treatment
replicate. The final estimate is:

mean across treatment tanks of (response - baseline posterior mean)
minus mean across control tanks of (response - baseline posterior mean).

A bootstrap resamples **tanks within treatment arms**, never
fish or video frames. Its percentile interval is a descriptive
resampling sensitivity interval; its actual coverage is uncalibrated.

## Timing and optical boundaries

Event onsets must already be expressed on the same validated clock
as fish trajectories. Camera-clock drift and physical fish source
correspondences still require independent evidence. Posterior means
are **sample-weighted**, not time-weighted; if recording is irregular,
time-weighted observational dwell estimates or an explicit
continuous-time model are scientifically distinct requirements.

No attempt is made to propagate camera, refraction, detector,
biological identity or HMM parameter uncertainty into the final
contrast. HMM state numbers are mathematical categories, not
validated species-specific behaviour or physiological stress labels.
Neither this contrast nor bootstrap bands establish causal effects
without an appropriate independent-tank experimental design.

## Next development gates

- Real synchronized recorded events and multi-camera data.
- Robust event timing/error ensembles propagated through HMM posteriors.
- Repeated-event, nested, AR-dependent and staggered-tank designs.
- Independent animal behavioural annotations and relevant welfare
  indicators across species, growth stages and contexts.
- Measurement-sensitivity, power, interval coverage and honest
  treatment-effect simulations with independent replicate tanks.
