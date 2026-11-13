% Generated with the AquaTrajectories publication visualization suite
\name{aqt_plot_feeding_states}
\alias{aqt_plot_feeding_states}
\title{Plot externally labelled feeding-behaviour states}
\usage{
aqt_plot_feeding_states(
  data,
  scenario_col = "scenario",
  time_col = "time_min",
  index_col = "fbi",
  phase_col = "phase",
  event_time_min = 0,
  index_limits = c(0, 1),
  phase_colors = c(pre = "#24292F", onset = "#E53935", later = "#9CA3AF",
    post = "#3055EE")
)
}
\arguments{
\item{data}{Long data.frame with scenario, time, measured index and supplied phase labels.}
\item{scenario_col, time_col, index_col, phase_col}{Names of the columns in data.}
\item{event_time_min}{Known intervention start time in minutes.}
\item{index_limits}{Two finite increasing index limits; NULL uses observed extrema without clipping.}
\item{phase_colors}{Named colour vector covering every supplied phase.}
}
\value{
Invisibly a per-scenario and per-phase sample-count data.frame, with provenance attributes.
}
\description{
Produces up to four scatter panels for an externally calculated behavioural index and supplied phase labels.
}
\details{
The function does not derive feeding phases, calibrate the index or certify HMM/feeding behaviour. It refuses index clipping and unknown label colours.
}
