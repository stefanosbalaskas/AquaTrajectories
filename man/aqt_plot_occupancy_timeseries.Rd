% Generated with the AquaTrajectories publication visualization suite
\name{aqt_plot_occupancy_timeseries}
\alias{aqt_plot_occupancy_timeseries}
\title{Plot across-tank spatial occupancy time series}
\usage{
aqt_plot_occupancy_timeseries(
  data,
  time_bin_s = 60,
  band = c("sd", "se", "none"),
  periods = NULL
)
}
\arguments{
\item{data}{Long data.frame with scenario, tank_id, time_s, area_fraction between zero and one.}
\item{time_bin_s}{Positive time-bin width in seconds.}
\item{band}{Descriptive between-tank SD, SE, or no band; no bands for a single tank.}
\item{periods}{Optional table with known start_s, end_s and label columns for shaded experimental periods.}
}
\value{
Invisibly a time-binned summary with equal weighting per tank, tank counts and descriptive SD/SE.
}
\description{
Plots time series of spatial occupancy by scenario with optional between-tank shaded uncertainty and experimental intervals.
}
\details{
Data must contain measured area fractions. Rows are first averaged within tank/time bin; individual fish frames are not counted as independent tank replicates. Bands are not confidence intervals and do not establish inferential significance.
}
