# Wave 13D: estimated fish detector misses as conditional observation scenarios.
# This does NOT calibrate a biological outcome or confidence interval.

#' Simulate temporally correlated fish-detection dropout in recorded tracks
#'
#' Preserves existing unobserved fish, video timestamps, identity scope and
#' original track rows. For each fish, generate a two-state Markov missingness
#' process with stationary probability p_missing and persistence rho. Tracks
#' are not interpolated, and lost observations have NA coordinates. These
#' assumptions must be externally estimated before any scientific accuracy
#' or uncertainty coverage can be claimed. Original fish or tank counts are
#' never increased by the number of frame-level scenarios.
#'
#' @param tracks Original validated aqt_tracks 2D or 3D.
#' @param p_missing Assumed fraction of currently observed fish rows dropped.
#' @param persistence Markov temporal persistence in [0,1). Values near one
#'   produce correlated occlusion/missing-detection bursts within fish.
#' @param draws Number of sensitivity scenarios (1 through 1000).
#' @param seed Reproducible RNG seed with caller state restored.
#' @return aqt_detection_dropout_scenarios list with original frame-scope
#'   rows, conditional draws, per-draw coverage and assumptions.
#' @export
aqt_detection_dropout_scenarios <- function(
    tracks,p_missing,persistence=0.5,draws=100L,seed=42L) {
  aqt_tracks_validate(tracks)
  validate_scalar <- function(x,name,lower,upper,strict_upper=FALSE) {
    if (!is.numeric(x) || length(x)!=1L || !is.finite(x) ||
        x<lower || (if (strict_upper) x>=upper else x>upper))
      stop("Invalid ",name,call.=FALSE)
  }
  validate_scalar(p_missing,"p_missing",0,1)
  validate_scalar(persistence,"persistence",0,1,TRUE)
  validate_scalar(draws,"draws",1,1000)
  validate_scalar(seed,"seed",0,2147483000)
  if (draws!=floor(draws) || seed!=floor(seed))
    stop("draws/seed must be integers",call.=FALSE)
  if (as.double(draws)*nrow(tracks)>300000)
    stop("Dropout scenario budget exceeded: 300,000 positions",call.=FALSE)
  original <- as.data.frame(tracks)
  if (!nrow(original)) stop("Cannot assess dropout on empty fish tracks",call.=FALSE)
  if (!is.logical(original$observed) || anyNA(original$observed))
    stop("Original fish observed flags are invalid",call.=FALSE)
  groups <- split(seq_len(nrow(original)),
    interaction(original$session_id,original$camera_id,
                original$track_id,drop=TRUE))
  had <- exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE)
  if (had) old <- get(".Random.seed",envir=.GlobalEnv)
  on.exit({
    if (had) assign(".Random.seed",old,envir=.GlobalEnv)
    else if (exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
      rm(".Random.seed",envir=.GlobalEnv)
  },add=TRUE)
  set.seed(as.integer(seed))
  data <- vector("list",as.integer(draws))
  coverage <- vector("list",as.integer(draws))
  p11 <- p_missing+persistence*(1-p_missing)
  p01 <- p_missing*(1-persistence)
  for (draw in seq_len(draws)) {
    x <- original
    added <- rep(FALSE,nrow(x))
    for (idx in groups) {
      idx <- idx[order(x$time_s[idx])]
      state <- stats::runif(1L)<p_missing
      for (j in idx) {
        if (state && x$observed[j]) added[j] <- TRUE
        state <- stats::runif(1L) <
          (if (state) p11 else p01)
      }
    }
    x$simulated_detection_dropout <- added
    x$observed[added] <- FALSE
    x$x[added] <- NA_real_
    x$y[added] <- NA_real_
    x$z[added] <- NA_real_
    data[[draw]] <- aqt_tracks(x,units=attr(tracks,"aqt_units"),
                                coordinate_system=attr(tracks,
                                                       "aqt_coordinate_system"))
    coverage[[draw]] <- data.frame(
      draw=draw,original_rows=nrow(x),
      original_observed=sum(original$observed),
      additional_missed=sum(added),
      remaining_observed=sum(x$observed),
      observed_fraction=mean(x$observed),
      additional_dropout_given_original_observed=
        if (sum(original$observed)) sum(added)/sum(original$observed) else NA_real_)
  }
  structure(list(tracks=data,coverage=do.call(rbind,coverage),
    assumptions=list(p_missing=p_missing,persistence=persistence,
      transition_p11=p11,transition_p01=p01,
      draws=as.integer(draws),seed=as.integer(seed),
      source_observation_timestamps_preserved=TRUE,
      input_detection_rate_independently_calibrated=FALSE,
      interval_coverage_calibrated=FALSE,
      official_fish_identity_metrics_computed=FALSE,
      physical_3d_position_accuracy_certified=FALSE,
      animal_welfare_validated=FALSE)),
    class="aqt_detection_dropout_scenarios")
}

#' Recompute externally logged behavioural event epochs after detection losses
#'
#' Produces descriptive per-fish event epoch statistics for every conditional
#' dropout draw, requiring each draw to have estimable observations. Inference
#' about treatment effects needs externally randomized independent tanks and
#' additional measurement-error calibration.
#'
#' @param scenarios Output from aqt_detection_dropout_scenarios.
#' @param events Session,event_id,start_s,end_s source event table.
#' @param outcome Numeric output of aqt_kinematics, default speed.
#' @param windows Ordered, nonoverlapping event windows in seconds.
#' @param max_gap_s Maximum observed interval for kinematics.
#' @param min_points Minimum observed finite values per epoch.
#' @return Long data frame with draw, external fish/event/epoch and counts.
#' @export
aqt_detection_event_sensitivity <- function(
    scenarios,events,outcome="speed",
    windows=list(baseline=c(-3,0),response=c(0,3)),
    max_gap_s=Inf,min_points=1L) {
  if (!inherits(scenarios,"aqt_detection_dropout_scenarios") ||
      !is.list(scenarios$tracks) || !length(scenarios$tracks))
    stop("Expected detection dropout scenarios",call.=FALSE)
  output <- lapply(seq_along(scenarios$tracks),function(i) {
    features <- aqt_kinematics(scenarios$tracks[[i]],max_gap_s=max_gap_s)
    epoch <- aqt_event_epoch_summary(features,events,outcome=outcome,
      windows=windows,unit_cols=c("camera_id","track_id"),
      min_points=min_points,max_gap_s=max_gap_s)
    if (!nrow(epoch))
      stop("No estimable event outcome in dropout draw ",i,call.=FALSE)
    epoch$draw <- i
    epoch
  })
  result <- do.call(rbind,unname(output))
  rownames(result) <- NULL
  attr(result,"aqt_intervals_calibrated") <- FALSE
  attr(result,"aqt_tank_effect_identified") <- FALSE
  result
}
