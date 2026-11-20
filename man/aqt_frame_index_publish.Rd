\name{aqt_frame_index_publish}
\alias{aqt_frame_index_publish}
\title{Publish a frame-indexed observation-quality and movement report}
\usage{
aqt_frame_index_publish(study, directory)
}
\arguments{
\item{study}{Output of \code{aqt_frame_index_analyze()}.}
\item{directory}{A new destination directory whose parent already exists. Previous results are not overwritten.}
}
\value{
The new publication directory, invisibly.
}
\description{
Exports audited descriptive tables, an RDS scientific object, independent source-specific trajectory and group plots, PNG/SVG/vector-PDF figures, embedded-SVG self-contained HTML and Markdown reports, and an unkeyed SHA-256 output manifest. The figures do not infer physical time or establish animal identity accuracy.
}
