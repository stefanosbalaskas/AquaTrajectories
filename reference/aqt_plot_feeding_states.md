# Plot supplied feeding-behaviour phases against a measured index

Four-panel descriptive scatterplot comparing feeding scenarios. The
function never infers feeding from speed, HMM state, or clustering
alone: both the numerical index and biological phase labels MUST be
supplied. Thus rendering the figure is not validation of a feeding
index.

## Usage

``` r
aqt_plot_feeding_states(
  data,
  scenario_col = "scenario",
  time_col = "time_min",
  index_col = "fbi",
  phase_col = "phase",
  event_time_min = 0,
  index_limits = c(0, 1),
  phase_colors = c(pre = "#24292F", onset = "#E53935", later = "#9CA3AF", post =
    "#3055EE")
)
```

## Arguments

- data:

  Nonempty data.frame with columns scenario,time_min,fbi,phase (or
  alternative names selected by column arguments).

- scenario_col, time_col, index_col, phase_col:

  Column names.

- event_time_min:

  Known intervention onset; default zero minutes.

- index_limits:

  Numeric axis limits; default c(0,1) for a normalized fraction. Set
  NULL to infer observed limits.

- phase_colors:

  Named vector of colour codes for the phase labels.

## Value

Invisibly, a data.frame with observations per supplied phase and
scenario; attributes explicitly state the labels are not verified.
