% Generated with the AquaTrajectories publication visualization suite
\name{aqt_plot_calibration_comparison}
\alias{aqt_plot_calibration_comparison}
\title{Compare held-out XYZ reconstruction errors}
\usage{
aqt_plot_calibration_comparison(
  data,
  units = c("cm", "m"),
  require_holdout = TRUE
)
}
\arguments{
\item{data}{Long data.frame with method, target_id, partition, truth_x, truth_y, truth_z, estimate_x, estimate_y and estimate_z.}
\item{units}{Physical coordinates and error units: cm or m.}
\item{require_holdout}{Require explicit holdout partition and prevent target ID overlap between fit and holdout subsets.}
}
\value{
Invisibly a per-method table of Euclidean 3D RMSE, mean error, maximum error, axis biases and target counts.
}
\description{
Displays Euclidean XYZ error densities and error-coloured axonometric maps of reference targets by calibration method.
}
\details{
This computes nonnegative radial XYZ position residuals, not signed inter-target distance errors. External physical target surveying, train/test independence beyond labels and absolute calibration accuracy require independent validation.
}
