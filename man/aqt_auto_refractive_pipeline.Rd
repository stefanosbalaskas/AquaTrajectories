\name{aqt_auto_refractive_pipeline}
\alias{aqt_auto_refractive_pipeline}
\title{Automatic two-camera fish association and refractive 3D reconstruction}
\usage{
aqt_auto_refractive_pipeline(view_a, view_b, camera_a, camera_b,
  max_skew_s = 0.02, max_ray_separation = 0.5,
  min_support = 3L, ambiguity_margin = 0.05,
  max_candidates = 100000L)
}
\arguments{
\item{view_a, view_b}{Two synchronized-camera pixel \code{aqt_tracks}, with externally checked timestamps.}
\item{camera_a, camera_b}{Compatible externally calibrated refractive models.}
\item{max_skew_s}{Timestamp tolerance in seconds.}
\item{max_ray_separation}{Maximum physically permitted ray-separation residual.}
\item{min_support}{Minimum temporal match count for a stable camera-pair identity.}
\item{ambiguity_margin}{Required separation from competing geometric pair errors.}
\item{max_candidates}{Maximum cross-camera geometric candidate count.}
}
\value{Object \code{aqt_auto_refractive_pipeline} containing candidate table,
cross-camera stable associations, \code{tracks_3d} or \code{NULL} if none,
diagnostics, and explicit physical/biological certification flags.}
\description{Integrated native 2D matching to refractive 3D trajectory pipeline.}
\details{Requires actual camera-side 2D trajectories and separately calibrated
camera clocks and refractive parameters. It does not execute video detection,
prove hardware synchronization, or certify physical XYZ or fish identity.}
