# Decode bounded fish behavioural states under an explicit Gaussian HMM

Uses caller-specified (NOT learned) Gaussian state means and standard
deviations, an initial distribution and a row-stochastic transition
matrix. Forward-backward yields observation-conditional posterior state
probabilities; Viterbi yields a single descriptive state sequence.
Different fish, sessions, cameras and tanks are never joined. Missing
observations, invalid observed flags and time gaps above max_gap_s break
the Markov chain. Short valid runs remain explicitly unclassified. State
names do not establish fish stress, welfare, preference or causal
responses. No treatment p-values or uncertainty calibration are
supplied.

## Usage

``` r
aqt_hmm_decode(
  data,
  outcome = "speed",
  state_means,
  state_sds,
  transition,
  initial = NULL,
  state_labels = NULL,
  max_gap_s = 0.5,
  min_segment = 3L
)
```

## Arguments

- data:

  Data frame with session_id,camera_id,track_id,time_s and a numeric
  outcome. Optional observed,tank_id,treatment are preserved.

- outcome:

  Name of observed numeric measure (default speed).

- state_means:

  Strictly increasing externally justified state means.

- state_sds:

  Positive Gaussian SD per state.

- transition:

  K-by-K row-stochastic transition probabilities.

- initial:

  Optional initial probability vector; equal by default.

- state_labels:

  Optional distinct nonempty descriptive names.

- max_gap_s:

  Maximum elapsed time to join adjacent samples.

- min_segment:

  Minimum consecutive observed samples to decode.

## Value

aqt_hmm_states with posterior hmm_p1..hmm_pK, Viterbi state, entropy,
explicit missingness, segments and model/likelihood metadata.
