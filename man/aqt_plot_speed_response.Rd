% Generated with the AquaTrajectories publication visualization suite
\name{aqt_plot_speed_response}
\alias{aqt_plot_speed_response}
\title{Plot time-aligned swimming speed and tank-level responses}
\usage{
aqt_plot_speed_response(
  data,
  event_time_s,
  baseline_s = c(-30, 0),
  response_s = c(0, 30),
  speed_unit = NULL,
  tank_col = "tank_id",
  time_bin_s = 1,
  max_gap_s = 0.2
)
}
\arguments{
\item{data}{Kinematic data.frame containing tank_id, time_s and speed; or an aqt_tracks object with an independent tank identifier.}
\item{event_time_s}{Known stimulus or intervention onset in the trajectory time scale.}
\item{baseline_s, response_s}{Finite nonoverlapping event-relative time intervals.}
\item{speed_unit}{Explicit physical measurement unit, such as cm/s. For valid aqt_tracks with physical units, it can be derived.}
\item{tank_col}{Column identifying the independent experimental unit.}
\item{time_bin_s}{Positive width for tank-equal-weight time summaries.}
\item{max_gap_s}{Maximum contiguous observed step time when aqt_tracks is supplied.}
}
\value{
Invisibly a list with time_bins, per_tank_time_bins, per_tank_epoch and summary data frames.
}
\description{
Plots intervention-aligned tank-level speed traces and paired baseline-versus-response tank summaries.
}
\details{
The plots show descriptive means and SD, not statistical tests. Experiment time, animal welfare, tank independence and any speed conversion must be validated by the researcher.
}
