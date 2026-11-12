\name{aqt_multiview_holdout_protocol}
\alias{aqt_multiview_holdout_protocol}
\title{Combine disjoint camera-clock and surveyed underwater target holdout audits}
\usage{
aqt_multiview_holdout_protocol(markers, surveyed_targets, cameras,
  reference_camera, train_markers, holdout_markers,
  max_holdout_error_s = 0.005, max_ray_separation = Inf,
  target_units = c("cm", "m"))
}
\arguments{
\item{markers}{Original session/camera/marker/time data for physically
corresponding camera exposures. Their independence must be checked externally.}
\item{surveyed_targets}{Independent physical target-trial table, including
disjoint fit and holdout target assemblies.}
\item{cameras}{Named refractive camera models, previously calibrated.}
\item{reference_camera}{One camera present in both marker/target tables.}
\item{train_markers,holdout_markers}{Disjoint physically corresponding
marker ID sets, at least four and two respectively.}
\item{max_holdout_error_s}{Prespecified positive maximum clock residual in seconds.}
\item{max_ray_separation}{Accepted ray separation in physical XYZ units.}
\item{target_units}{Physical target position units, cm or m.}
}
\value{
An \code{aqt_multiview_holdout_protocol} with original holdout
clock diagnostics, physically surveyed holdout target error
results, software qualification summary and explicitly false
independent-hardware/survey/physical certification flags.
}
\description{
Runs existing R synchronization and external-target holdout scorers
as one two-view validation protocol, rejecting missing session-camera
correspondence. Source pulse validity, physical survey independence,
frozen camera fitting, actual optical conditions, expert fish
cross-view identity and scientific accuracy remain independent tasks.
}
