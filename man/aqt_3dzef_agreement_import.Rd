\name{aqt_3dzef_agreement_import}
\alias{aqt_3dzef_agreement_import}
\title{Import a SHA-256-verified 3D-ZeF published-label agreement report}
\usage{
aqt_3dzef_agreement_import(directory)
}
\arguments{
\item{directory}{Existing folder containing \code{summary.json}, \code{per_frame.csv}, and \code{matches.csv} produced by \code{aqt_3dzef_agreement.py}.}
}
\value{
An \code{aqt_3dzef_label_agreement} list containing \code{summary},
\code{per_frame}, \code{matches}, and
\code{software_integrity_verified = TRUE}; never a claim that
independent physical underwater XYZ or fish model accuracy was verified.
}
\description{
Verifies Python agreement report digests, row accounting, source coordinate
units, scope and matched 3D Euclidean errors in centimetres. The source labels
are published tracking annotations, not independently surveyed fish positions.
Unkeyed SHA-256 cannot authenticate the model or reviewer.
}
\details{
Only original 3D-ZeF published-label agreement is imported. This operation
does not calculate official ZF3D MOTA or TrackEval HOTA, does not establish
cross-camera hardware synchronization, and cannot infer animal welfare or
stress from the imported information.
}
