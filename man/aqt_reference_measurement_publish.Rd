\name{aqt_reference_measurement_publish}
\alias{aqt_reference_measurement_publish}
\title{Export numerical source-linked fish measurement validation}
\usage{
aqt_reference_measurement_publish(study, directory)
}
\arguments{
\item{study}{Output of aqt_reference_measurement_validate.}
\item{directory}{New output directory; parent must exist.}
}
\value{
New destination directory invisibly.
}
\description{
This writes the already-computed source-preserving M08 measurement audit. Reports are descriptive and explicitly withhold unmeasured physical/biological conclusions; original frames and fish observations are not modified.
}
