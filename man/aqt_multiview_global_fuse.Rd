\name{aqt_multiview_global_fuse}
\alias{aqt_multiview_global_fuse}
\title{Fuse globally consistent provisional identities from three or more cameras}
\usage{
aqt_multiview_global_fuse(pairwise_results, min_views = 2L,
  max_disagreement = 0.5)
}
\arguments{
\item{pairwise_results}{Named automatic refractive pipeline outputs from
a shared reference camera to distinct secondary cameras.}
\item{min_views}{Minimum contributing total camera views (at least two).}
\item{max_disagreement}{Maximum accepted disagreement of source-pairwise
3D XYZ estimates, in declared world physical units.}
}
\value{An \code{aqt_multiview_global_fusion} object containing globally
consistent provisional reference-fish identities, native
\code{aqt_tracks} 3D positions or \code{NULL}, per-source observation
counts, camera view support and rejected incompatible candidates.}
\description{Fuse verified one-to-one pairwise geometric fish hypotheses
into one provisional reference-anchored 3D trajectory per fish.}
\details{The matched tracks remain provisional geometric hypotheses:
this function never independently certifies biological identity, actual
camera exposure time, physical surveyed XYZ or fish welfare.}
