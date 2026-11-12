\name{aqt_detection_event_sensitivity}
\alias{aqt_detection_event_sensitivity}
\title{Recompute behavioural event epochs across detection-loss scenarios}
\usage{
aqt_detection_event_sensitivity(scenarios, events, outcome = "speed",
  windows = list(baseline = c(-3, 0), response = c(0, 3)),
  max_gap_s = Inf, min_points = 1L)
}
\arguments{
\item{scenarios}{Output from \code{aqt_detection_dropout_scenarios}.}
\item{events}{External event table with session_id, event_id, start_s, end_s.}
\item{outcome}{Numeric kinematic outcome (default \code{speed}).}
\item{windows}{Named chronological, non-overlapping time windows relative to events.}
\item{max_gap_s}{Maximum valid observed gap in seconds for kinematics.}
\item{min_points}{Minimum observed finite points to estimate each event epoch.}
}
\value{
Long per-draw, per-fish external-event descriptive summaries with calibration
and independent tank treatment-effect flags set to false.
}
\description{
Recomputes kinematics and event-aligned descriptive statistics for every
conditional detection dropout scenario. Does not interpret fish frames as
independent treatment replication or estimate validated causal, calibrated
uncertainty or welfare effects.
}
