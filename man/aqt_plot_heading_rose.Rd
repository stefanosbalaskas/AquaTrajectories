% Generated with the AquaTrajectories publication visualization suite
\name{aqt_plot_heading_rose}
\alias{aqt_plot_heading_rose}
\title{Plot circular swimming-heading distributions}
\usage{
aqt_plot_heading_rose(
  data,
  bins = 16L,
  scale = c("fraction", "count"),
  clockwise = FALSE,
  zero_offset_rad = 0,
  weight_col = NULL,
  frame_rasters = NULL,
  fill = "#B0C36B"
)
}
\arguments{
\item{data}{Long data.frame with condition and heading_rad; planar angles are in radians.}
\item{bins}{Integer number of directional sectors between 4 and 72.}
\item{scale}{Radial scale: fraction of valid positive-weight headings or weighted count.}
\item{clockwise}{Whether input heading angles increase clockwise rather than counter-clockwise.}
\item{zero_offset_rad}{Offset of angle zero in radians.}
\item{weight_col}{Optional positive or nonnegative weight column for circular bin frequencies.}
\item{frame_rasters}{Optional named list of already-loaded image rasters for pairing source video frames with the rose plots.}
\item{fill}{Valid sector fill colour.}
}
\value{
Invisibly a per-condition per-bin table with circular descriptive statistics and excluded-observation metadata.
}
\description{
Plots up to six direction rose panels, optionally paired with externally supplied representative frame images.
}
\details{
This is a 2D projected-heading chart, not a 3D orientation estimate. An image-coordinate convention, camera orientation and phase labels require independent confirmation before biological interpretation.
}
