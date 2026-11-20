\name{aqt_frame_index_analyze}
\alias{aqt_frame_index_analyze}
\title{Frame-indexed aquatic movement and group-geometry analysis}
\usage{
aqt_frame_index_analyze(
  frames,
  observations,
  occupancy_bins = 8L,
  max_fish_per_frame = 200L
)
}
\arguments{
\item{frames}{Data frame: data_path, session_id, camera_id, frame_id, width_px, height_px, time_s. Frames must be complete 0..N-1 in each scope; time_s must be blank or NA.}
\item{observations}{Data frame: data_path, session_id, camera_id, frame_id, track_id, x, y. These are observed bounding-box centres in image pixels. The source-specific bounding boxes, confidence, and annotation status are preserved if present.}
\item{occupancy_bins}{Integer number of image-normalized occupancy bins per dimension; 2..50.}
\item{max_fish_per_frame}{Maximum individuals for pairwise geometry computation per frame; 2..200.}
}
\value{
A list of the original source rows, complete-frame coverage, adjacent-frame displacements, within-frame group geometry, observed occupancy, per-scope descriptive summaries and warnings; class \code{aqt_frame_index_study}.
}
\description{
Computes descriptive image-pixel movement metrics when measured image timestamps are unavailable. Only consecutive recorded frames within one camera-local track yield displacement; gaps never bridge. No physical velocity, experimental event inference, independent biological fish identification, or reference-to-model ID matching is claimed.
}
