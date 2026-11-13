\name{aqt_crossview_auto_associate}
\alias{aqt_crossview_auto_associate}
\title{Select stable provisional fish identities across camera views}
\usage{
aqt_crossview_auto_associate(candidates, min_support = 3L,
  max_error = 0.5, ambiguity_margin = 0.05)
}
\arguments{
\item{candidates}{Original refractive ray separation or pinhole reprojection candidates.}
\item{min_support}{Minimum distinct one-to-one observation pairs per stable match.}
\item{max_error}{Maximum eligible physical ray residual or pinhole pixel residual.}
\item{ambiguity_margin}{Required margin against geometrically tied competing links.}
}
\value{Object \code{aqt_crossview_association} with \code{correspondences},
\code{links}, original candidate counts and provisional identity caveats.}
\description{Automatically choose geometrically supported, temporally stable,
one-to-one camera-local track-pair hypotheses; abstain on unresolved ties.}
\details{Automatic camera-local track association is not independently
reviewed biological animal re-identification.}
