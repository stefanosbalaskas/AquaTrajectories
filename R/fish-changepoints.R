# Descriptive change-point segmentation of one observed fish outcome path.
# Mathematical penalized SSE, not biological state classification.

#' Detect penalized mean changes in one complete fish behaviour series
#'
#' Finds global optimal piecewise-constant means under a user-declared
#' nonnegative squared-unit penalty per additional segment and minimum
#' sample count per segment. No hidden interpolation, time warping,
#' statistical p-values or causal claims. This is a descriptive model.
#' Irregular timestamps are retained but the SSE objective weights
#' samples equally, not by duration; for irregular high-rate recordings
#' use externally justified pre-aggregation before comparing experiments.
#'
#' @param data Data frame with a single session_id/camera_id/track_id,
#'   strictly ordered unique time_s and a finite numeric outcome.
#' @param outcome Name of observed numeric behaviour feature, e.g. speed.
#' @param penalty Nonnegative cost in squared outcome units per break.
#' @param min_segment Minimum observations in every segment (>=3).
#' @param max_gap_s Largest allowed time interval; gaps raise errors.
#' @return aqt_changepoints with segment means, change-point time
#'   midpoints and a fully audited objective.
#' @export
aqt_state_changepoint <- function(data,outcome="speed",
                                  penalty,min_segment=5L,
                                  max_gap_s=Inf) {
  req <- c("session_id","camera_id","track_id","time_s",outcome)
  if (!is.data.frame(data) || !all(req %in% names(data)))
    stop("Expected one complete fish outcome trajectory",call.=FALSE)
  if (!is.character(outcome) || length(outcome)!=1L ||
      !is.numeric(data[[outcome]]))
    stop("outcome must name a numeric behaviour measure",call.=FALSE)
  if (any(!is.finite(data[[outcome]])) ||
      !is.numeric(data$time_s) || any(!is.finite(data$time_s)))
    stop("Missing/nonfinite outcomes or timestamps; segment or audit gaps first",
         call.=FALSE)
  if ("observed" %in% names(data) && any(!data$observed))
    stop("Non-observed samples must be removed or handled explicitly",
         call.=FALSE)
  if (!is.numeric(penalty) || length(penalty)!=1L ||
      !is.finite(penalty) || penalty<0)
    stop("penalty must be a finite nonnegative squared-outcome cost",
         call.=FALSE)
  if (!is.numeric(min_segment) || length(min_segment)!=1L ||
      !is.finite(min_segment) || min_segment<3L ||
      min_segment!=floor(min_segment))
    stop("min_segment must be integer >=3",call.=FALSE)
  if (!is.numeric(max_gap_s) || length(max_gap_s)!=1L ||
      is.na(max_gap_s) || max_gap_s<=0)
    stop("max_gap_s must be positive",call.=FALSE)
  for (nm in c("session_id","camera_id","track_id")) {
    v <- as.character(data[[nm]])
    if (anyNA(v) || length(unique(v))!=1L)
      stop("Change-point detection requires one scoped fish track",
           call.=FALSE)
  }
  d <- data[order(data$time_s),,drop=FALSE]
  tt <- d$time_s
  n <- nrow(d)
  if (n<2L*min_segment || n>1500L)
    stop("Require two potential segments and <=1500 observed samples",
         call.=FALSE)
  if (any(diff(tt)<=0) || any(diff(tt)>max_gap_s))
    stop("Duplicate timestamps or gaps exceed max_gap_s",call.=FALSE)
  y <- as.numeric(d[[outcome]])
  sy <- c(0,cumsum(y))
  syy <- c(0,cumsum(y*y))
  sse <- function(from,to) {
    k <- to-from+1L
    total <- sy[to+1L]-sy[from]
    total2 <- syy[to+1L]-syy[from]
    max(0,total2-total^2/k)
  }
  dp <- rep(Inf,n+1L)
  last <- rep(NA_integer_,n+1L)
  dp[1L] <- -penalty
  for (end in seq.int(as.integer(min_segment),n)) {
    starts <- seq_len(end-as.integer(min_segment)+1L)
    eligible <- starts[is.finite(dp[starts])]
    if (!length(eligible)) next
    values <- vapply(eligible,function(from)
      dp[from]+sse(from,end)+penalty,numeric(1L))
    best <- which.min(values)
    dp[end+1L] <- values[best]
    last[end+1L] <- eligible[best]-1L
  }
  if (!is.finite(dp[n+1L]))
    stop("No permissible segmentation under declared minimum duration",
         call.=FALSE)
  segments <- list()
  end <- n
  while (end>0L) {
    previous <- last[end+1L]
    if (is.na(previous) || previous<0L || previous>=end)
      stop("Internal change-point traceback failure",call.=FALSE)
    segments[[length(segments)+1L]] <- c(previous+1L,end)
    end <- previous
  }
  bounds <- do.call(rbind,rev(segments))
  fitted <- numeric(n)
  detail <- data.frame(segment=seq_len(nrow(bounds)),
     start_index=bounds[,1],end_index=bounds[,2],
     start_s=tt[bounds[,1]],end_s=tt[bounds[,2]],
     n_observations=bounds[,2]-bounds[,1]+1L,
     mean_value=NA_real_,within_sse=NA_real_)
  for (i in seq_len(nrow(bounds))) {
    idx <- seq.int(bounds[i,1L],bounds[i,2L])
    detail$mean_value[i] <- mean(y[idx])
    detail$within_sse[i] <- sse(bounds[i,1L],bounds[i,2L])
    fitted[idx] <- detail$mean_value[i]
  }
  cutindex <- if (nrow(bounds)>1L)
    bounds[seq_len(nrow(bounds)-1L),2L] else integer()
  changes <- if (length(cutindex))
    (tt[cutindex]+tt[cutindex+1L])/2 else numeric()
  structure(list(
    session_id=as.character(d$session_id[1L]),
    camera_id=as.character(d$camera_id[1L]),
    track_id=as.character(d$track_id[1L]),
    outcome=outcome,time_s=tt,observed=y,fitted=fitted,
    break_after_index=as.integer(cutindex),
    change_time_s=as.numeric(changes),
    segments=detail,n_segments=nrow(detail),
    penalty=penalty,min_segment=as.integer(min_segment),
    penalized_objective=dp[n+1L],
    interpretation="descriptive piecewise mean, not inferred stress or causal transition",
    empirical_significance_test=FALSE),
    class="aqt_changepoints")
}

#' Describe delay from a logged event to the next observed change point
#'
#' Searches first mean change after event onset within max_delay_s.
#' The returned delay is a descriptive temporal association, not
#' physiological response latency or evidence of an intervention effect.
#'
#' @param fit aqt_changepoints from one scoped session/camera/fish.
#' @param events Canonical event log for the same session.
#' @param max_delay_s Nonnegative finite window after each event onset.
#' @return Per-event observed change time and delay, NA if absent.
#' @export
aqt_changepoint_event_delay <- function(fit,events,max_delay_s=30) {
  if (!inherits(fit,"aqt_changepoints"))
    stop("Expected aqt_changepoints",call.=FALSE)
  if (!is.numeric(max_delay_s) || length(max_delay_s)!=1L ||
      !is.finite(max_delay_s) || max_delay_s<0)
    stop("max_delay_s must be finite and nonnegative",call.=FALSE)
  e <- aqt_event_table(events)
  e <- e[e$session_id==fit$session_id,,drop=FALSE]
  if (!nrow(e)) stop("No events in the fitted fish session",call.=FALSE)
  found <- vapply(e$start_s,function(start) {
    candidate <- fit$change_time_s[
      fit$change_time_s>=start &
      fit$change_time_s<=start+max_delay_s]
    if (length(candidate))min(candidate) else NA_real_
  },numeric(1L))
  data.frame(session_id=e$session_id,event_id=e$event_id,
    camera_id=fit$camera_id,track_id=fit$track_id,
    event_onset_s=e$start_s,
    change_time_s=found,delay_s=found-e$start_s,
    has_change=is.finite(found))
}

#' Plot observed fish behaviour and descriptive detected change points
#'
#' @param fit aqt_changepoints.
#' @return Fit invisibly; generates a base R diagnostic.
#' @export
aqt_plot_changepoints <- function(fit) {
  if (!inherits(fit,"aqt_changepoints") ||
      !is.numeric(fit$time_s) || !is.numeric(fit$fitted))
    stop("Expected aqt_changepoints result",call.=FALSE)
  graphics::plot(fit$time_s,fit$observed,type="p",pch=16,
    cex=.45,col="#56687D",
    xlab="Recording time (seconds)",ylab=fit$outcome,
    main="Observed fish behaviour and descriptive mean changes")
  graphics::lines(fit$time_s,fit$fitted,col="#B34A35",lwd=2)
  if (length(fit$change_time_s))
    graphics::abline(v=fit$change_time_s,lty=3,
                     col="#555555")
  invisible(fit)
}
