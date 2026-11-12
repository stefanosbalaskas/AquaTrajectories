\name{aqt_detection_dropout_scenarios}
\alias{aqt_detection_dropout_scenarios}
\title{Simulate temporally correlated fish-detection misses as conditional sensitivity scenarios}
\usage{
aqt_detection_dropout_scenarios(tracks, p_missing, persistence = 0.5, draws = 100L, seed = 42L)
}
\arguments{
\item{tracks}{Original validated \code{aqt_tracks} in 2D or 3D.}
\item{p_missing}{Assumed stationary probability of missing an originally observed fish row, between zero and one.}
\item{persistence}{Within-fish temporal correlation parameter in [0,1).}
\item{draws}{Positive integer sensitivity draws (at most 1000).}
\item{seed}{Reproducible integer RNG seed. The original RNG state is restored.}
}
\value{
An \code{aqt_detection_dropout_scenarios} object with
\code{tracks} (complete original time-scope rows, additional missing
positions set to NA), \code{coverage}, and \code{assumptions}.
}
\description{
Constructs a fish-scoped, two-state Markov missingness process on genuine
observed rows while preserving all original source timestamps, existing
missing observations and track identifiers. Parameters are user-assumed
sensitivity inputs; this does not calibrate observation probabilities
or confidence interval coverage.
}
\details{
Transitions are defined by stationary missingness p and persistence rho:
P(drop_next | drop_previous) = p + rho * (1-p);
P(drop_next | observed_previous) = p * (1-rho).
Simulated fish frames are not new independent replicates. No original
fish detection, camera calibration or physical 3D accuracy is certified.
}
