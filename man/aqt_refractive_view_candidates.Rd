\name{aqt_refractive_view_candidates}
\alias{aqt_refractive_view_candidates}
\title{Generate unreviewed cross-camera refractive fish match candidates}
\usage{
aqt_refractive_view_candidates(view_a, view_b, camera_a, camera_b,
  max_skew_s = 0.02, max_ray_separation = 0.5,
  max_candidates = 100000L)
}
\arguments{
\item{view_a, view_b}{Two valid camera-local 2D image-space pixel \code{aqt_tracks}.}
\item{camera_a, camera_b}{Externally calibrated compatible refractive camera models.}
\item{max_skew_s}{Maximum timestamp skew after externally applied camera alignment.}
\item{max_ray_separation}{Maximum physically permitted closest-ray residual.}
\item{max_candidates}{Maximum number of time-compatible fish candidate pairs.}
}
\value{Source-paired stereo candidate data frame with image, time, fish track,
refractive XYZ, ray residual and validity. No biological identity certified.}
\description{Generate geometrically plausible fish-pair hypotheses by tracing
camera-local detections through two calibrated refractive models.}
\details{Camera exposure synchronization, intrinsic/extrinsic calibration and
animal identity are external responsibilities. Original source video data
are never used as ground-truth identities by this function.}
