# Trajectory sensitivity ensembles. Deliberately conditional on a caller-specified
# noise scenario, not fitted uncertainty distributions or confidence intervals.
# No ID switches, missingness mechanism, refraction, camera clock uncertainty,
# or biological/tank-level sampling variation are modeled in this first module.

.aqt_axes <- function(tracks) {
  c("x","y",if (identical(attr(tracks,"aqt_dimension"),3L)) "z")
}

.aqt_sd_vector <- function(x,dim,name) {
  if (!is.numeric(x) || !length(x) || !(length(x) %in% c(1L,dim)) ||
      any(!is.finite(x)) || any(x<0))
    stop(name," must be one nonnegative SD or one per coordinate axis",call.=FALSE)
  rep(x,length.out=dim)
}

#' Construct coherent measurement-error scenarios for 2D/3D fish trajectories
#'
#' Draws conditional additive position errors in the *same units as tracks*.
#' Each track's residual error is an AR(1) process across consecutive valid
#' observed samples, with a second, constant per-track offset for an optional
#' correlated systematic component. AR(1) is indexed by observations, not by
#' a physical continuous-time correlation model. Invalid/missing samples and
#' segments longer than max_gap_s reset the AR process. Fish identity is FIXED.
#'
#' This is a researcher-defined sensitivity model, not a calibrated error
#' model or a replacement for source video/annotation validation. The return
#' stores all simulated paths but does not change the original observations.
#'
#' @param tracks Validated aqt_tracks, 2D or 3D.
#' @param sigma Independent innovation marginal SD per coordinate axis.
#' @param rho Correlation parameter for AR(1), strictly between -1 and 1.
#' @param systematic_sd Constant position offset SD per scoped track and axis.
#' @param draws Number of conditional scenarios, >= 20.
#' @param seed Reproducible integer seed, preserving caller RNG.
#' @param max_gap_s Largest adjacent observation interval for AR continuation.
#' @return An aqt_trajectory_ensemble with base tracks, draws, and assumptions.
#' @export
aqt_trajectory_ensemble <- function(tracks,sigma=.1,rho=0,systematic_sd=0,
                                    draws=200L,seed=31L,max_gap_s=Inf) {
  aqt_tracks_validate(tracks)
  axis <- .aqt_axes(tracks)
  dd <- length(axis)
  sigma <- .aqt_sd_vector(sigma,dd,"sigma")
  systematic_sd <- .aqt_sd_vector(systematic_sd,dd,"systematic_sd")
  if (!is.numeric(rho) || length(rho)!=1L || !is.finite(rho) ||
      abs(rho)>=1)
    stop("rho must lie strictly between -1 and 1",call.=FALSE)
  if (!is.numeric(draws) || length(draws)!=1L || !is.finite(draws) ||
      draws<20L || draws!=floor(draws))
    stop("draws must be an integer >= 20",call.=FALSE)
  if (!is.numeric(seed) || length(seed)!=1L || !is.finite(seed) ||
      seed<0 || seed>2147483647 || seed!=floor(seed))
    stop("seed must be a nonnegative 32-bit integer",call.=FALSE)
  if (!is.numeric(max_gap_s) || length(max_gap_s)!=1L ||
      is.na(max_gap_s) || max_gap_s<=0)
    stop("max_gap_s must be positive",call.=FALSE)
  n <- nrow(tracks)
  if (as.double(n)*dd*draws > 2e6)
    stop("Scenario array too large; process a shorter subset",call.=FALSE)
  coords <- as.matrix(tracks[,axis,drop=FALSE])
  valid <- tracks$observed & stats::complete.cases(coords)
  base <- coords
  base[!valid,] <- NA_real_
  sims <- array(NA_real_,dim=c(n,dd,as.integer(draws)),
                dimnames=list(NULL,axis,NULL))
  scoped <- interaction(tracks$session_id,tracks$camera_id,
                        tracks$track_id,drop=TRUE)
  indices <- split(seq_len(n),scoped)
  had <- exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE)
  if (had) previous <- get(".Random.seed",envir=.GlobalEnv)
  on.exit({
    if (had) assign(".Random.seed",previous,envir=.GlobalEnv)
    else if (exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
      rm(".Random.seed",envir=.GlobalEnv)
  },add=TRUE)
  set.seed(as.integer(seed))
  for (b in seq_len(draws)) {
    y <- base
    for (idx in indices) {
      if (!length(idx)) next
      offset <- stats::rnorm(dd,sd=systematic_sd)
      state <- numeric(dd)
      prior <- NA_integer_
      for (i in idx) {
        if (!valid[i]) {
          prior <- NA_integer_
          state[] <- 0
          next
        }
        continue <- !is.na(prior) &&
          tracks$time_s[i]-tracks$time_s[prior]<=max_gap_s
        if (!continue) {
          state <- stats::rnorm(dd,sd=sigma)
        } else {
          state <- rho*state +
            stats::rnorm(dd,sd=sigma*sqrt(1-rho^2))
        }
        y[i,] <- base[i,]+offset+state
        prior <- i
      }
    }
    sims[,,b] <- y
  }
  structure(list(tracks=tracks,positions=sims,
    assumptions=list(sigma=sigma,rho=rho,systematic_sd=systematic_sd,
      max_gap_s=max_gap_s,draws=as.integer(draws),seed=as.integer(seed),
      conditional_on_fixed_identity=TRUE,
      excludes=c("cross-camera identity uncertainty",
        "camera rig calibration error","clock offsets","refraction",
        "missingness mechanism","experimental sampling variability"))),
    class="aqt_trajectory_ensemble")
}

#' Extract one complete trajectory scenario without altering the reference
#' @param ensemble An aqt_trajectory_ensemble.
#' @param draw Integer index of the desired scenario.
#' @return aqt_tracks with the same scope, units and observed flags.
#' @export
aqt_ensemble_tracks <- function(ensemble,draw=1L) {
  if (!inherits(ensemble,"aqt_trajectory_ensemble") ||
      !is.array(ensemble$positions) ||
      length(dim(ensemble$positions))!=3L ||
      !inherits(ensemble$tracks,"aqt_tracks"))
    stop("Expected aqt_trajectory_ensemble",call.=FALSE)
  shape <- dim(ensemble$positions)
  if (length(draw)!=1L || !is.numeric(draw) || !is.finite(draw) ||
      draw<1L || draw>shape[3L] || draw!=floor(draw))
    stop("Invalid scenario draw index",call.=FALSE)
  axis <- .aqt_axes(ensemble$tracks)
  if (shape[1L]!=nrow(ensemble$tracks) || shape[2L]!=length(axis))
    stop("Invalid scenario dimensions",call.=FALSE)
  mat <- ensemble$positions[,,as.integer(draw),drop=FALSE]
  dim(mat) <- c(shape[1L],shape[2L])
  d <- as.data.frame(ensemble$tracks)
  for (j in seq_along(axis)) d[[axis[j]]] <- mat[,j]
  out <- aqt_tracks(d,units=attr(ensemble$tracks,"aqt_units"),
                    coordinate_system=attr(ensemble$tracks,
                                           "aqt_coordinate_system"))
  attr(out,"aqt_scenario") <- as.integer(draw)
  out
}

#' Propagate spatial measurement scenarios into fish path statistics
#'
#' Returns one row per scoped fish and measurement-error draw. These are
#' conditional sensitivity calculations; the between-draw variance is
#' not biological or independent-tank sampling variance.
#' @param ensemble aqt_trajectory_ensemble.
#' @param max_gap_s Maximum valid movement segment for path summaries.
#' @return Long data frame of path length and time-weighted mean speed.
#' @export
aqt_ensemble_path_summary <- function(ensemble,max_gap_s=Inf) {
  if (!inherits(ensemble,"aqt_trajectory_ensemble"))
    stop("Expected aqt_trajectory_ensemble",call.=FALSE)
  n <- dim(ensemble$positions)[3L]
  out <- lapply(seq_len(n),function(i) {
    d <- aqt_path_summary(aqt_ensemble_tracks(ensemble,i),
                          max_gap_s=max_gap_s)
    if (!nrow(d)) return(NULL)
    d$draw <- i
    d
  })
  out <- Filter(Negate(is.null),out)
  if (!length(out)) return(data.frame())
  do.call(rbind,unname(out))
}

#' Propagate spatial noise scenarios into event-aligned fish behaviour
#'
#' Recomputes movement metrics independently for every trajectory draw,
#' then applies the existing event-epoch summarizer. No before/after
#' treatment effect is claimed by this measurement-only procedure.
#'
#' @param ensemble aqt_trajectory_ensemble.
#' @param events Event log.
#' @param outcome A numeric kinematic column such as speed or acceleration.
#' @param windows Named list of ordered event-relative time windows.
#' @param estimator sample_mean or time_weighted.
#' @param max_gap_s Largest movement and weighted-event segment interval.
#' @param min_points Minimum valid epoch samples.
#' @return Event epochs per fish and scenario draw.
#' @export
aqt_ensemble_event_summary <- function(
    ensemble,events,outcome="speed",
    windows=list(baseline=c(-120,0),response=c(0,120)),
    estimator=c("sample_mean","time_weighted"),
    max_gap_s=Inf,min_points=2L) {
  if (!inherits(ensemble,"aqt_trajectory_ensemble"))
    stop("Expected aqt_trajectory_ensemble",call.=FALSE)
  estimator <- match.arg(estimator)
  n <- dim(ensemble$positions)[3L]
  results <- lapply(seq_len(n),function(i) {
    features <- aqt_kinematics(aqt_ensemble_tracks(ensemble,i),
                               max_gap_s=max_gap_s)
    d <- aqt_event_epoch_summary(features,events,outcome=outcome,
      windows=windows,estimator=estimator,
      min_points=min_points,max_gap_s=max_gap_s)
    if (!nrow(d)) return(NULL)
    d$draw <- i
    d
  })
  results <- Filter(Negate(is.null),results)
  if (!length(results)) return(data.frame())
  do.call(rbind,unname(results))
}

#' Summarize across conditional trajectory measurement-error scenarios
#'
#' Each group should have at most one value per simulated draw. The
#' quantile interval is a sensitivity interval under the supplied error
#' assumptions, NEVER a validated confidence interval for treatment.
#' @param draws Long data frame from aqt_ensemble_* summary.
#' @param value_col Measurement column, such as mean_speed or value.
#' @param group_cols Identity/event columns defining one estimand.
#' @param level Fraction within the central empirical quantile interval.
#' @return Per-group conditional mean, SD, quantiles and draw count.
#' @export
aqt_ensemble_summarize <- function(draws,value_col,
                                   group_cols=c("session_id","camera_id","track_id"),
                                   level=.95) {
  if (!is.data.frame(draws) || !nrow(draws) ||
      !is.character(value_col) || length(value_col)!=1L ||
      !all(c(value_col,"draw",group_cols) %in% names(draws)))
    stop("Expected long scenario results, measure and grouping columns",call.=FALSE)
  if (!is.numeric(draws[[value_col]]))
    stop("Scenario measure must be numeric",call.=FALSE)
  if (!is.numeric(level) || length(level)!=1L || !is.finite(level) ||
      level<=0 || level>=1)
    stop("level must lie in (0,1)",call.=FALSE)
  if (!is.character(group_cols) || !length(group_cols) ||
      anyDuplicated(group_cols) || any(group_cols %in% c(value_col,"draw")))
    stop("Invalid scenario grouping columns",call.=FALSE)
  key <- do.call(paste,c(lapply(draws[group_cols],as.character),
                         list(sep="\r")))
  rows <- lapply(split(seq_len(nrow(draws)),key),function(idx) {
    x <- draws[idx,,drop=FALSE]
    if (anyDuplicated(x$draw))
      stop("More than one scenario estimate per group/draw",call.=FALSE)
    z <- x[[value_col]]
    z <- z[is.finite(z)]
    a <- if(length(z)>=2L) stats::sd(z) else NA_real_
    q <- if(length(z))
      unname(stats::quantile(z,c((1-level)/2,1-(1-level)/2),
                             names=FALSE))
      else rep(NA_real_,2L)
    result <- x[1L,group_cols,drop=FALSE]
    result$n_draws <- length(z)
    result$conditional_mean <- if (length(z)) mean(z) else NA_real_
    result$conditional_sd <- a
    result$lower <- q[1L]
    result$upper <- q[2L]
    result
  })
  out <- do.call(rbind,unname(rows))
  rownames(out) <- NULL
  attr(out,"aqt_interval_type") <- "conditional measurement sensitivity"
  out
}
