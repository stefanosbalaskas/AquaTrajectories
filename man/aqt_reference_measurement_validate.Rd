\name{aqt_reference_measurement_validate}
\alias{aqt_reference_measurement_validate}
\title{Validate fish trajectory measurements against declared reference annotations}
\usage{
aqt_reference_measurement_validate(
  frames,
  observations,
  matched,
  iou_threshold = 0.5
)
}
\arguments{
\item{frames}{Original M07 acquisition-frame table with unknown time_s.}
\item{observations}{Original M07 separate reference and model observation rows.}
\item{matched}{Evaluator one-to-one bbox associations with 1-based reference_source_row/model_source_row source-line indices.}
\item{iou_threshold}{Declared matching threshold in (0,1], default .5.}
}
\value{
A list containing source-preserving matching, complete reference adjacent-step ledger, matched-subset spatial geometry, a per-sequence measurement summary and explicit blocked physical/biological claims.
}
\description{
Compare image-pixel coordinates, adjacent-frame displacement and matched group geometry after external evaluation-only one-to-one IoU matching. The source observations remain unchanged and original fish references are NOT claimed as independently re-adjudicated biological identity truth.
}
