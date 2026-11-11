#' Define explicit candidate identity switches and draw coherent assignments
#'
#' Each candidate event swaps two CURRENT assigned tracker labels in ONE
#' session/camera, from an explicitly recorded time onward. There is no
#' automatic biological identity recognition and no probability estimation:
#' probabilities must be justified by independent annotations or sensitivity
#' assumptions. Swaps are sampled once per crossing event and applied to
#' entire subsequent track segments, not independently to each video frame.
#'
#' @param tracks Canonical aqt_tracks with unique scoped track IDs per time.
#' @param candidate_events Table with session_id, camera_id,
#'   track_a, track_b, at_s and probability_swap. All required.
#' @param draws Number of assignment scenarios (>= 1).
#' @param seed Integer RNG seed; preserves the global RNG state.
#' @return aqt_identity_scenarios containing original trajectories,
#'   candidate switch events, and a draw-by-event logical decision matrix.
#' @export
aqt_identity_switch_scenarios <- function(tracks,candidate_events,
                                          draws=200L,seed=7L) {
  aqt_tracks_validate(tracks)
  needed <- c("session_id","camera_id","track_a","track_b",
              "at_s","probability_swap")
  if (!is.data.frame(candidate_events) ||
      !all(needed %in% names(candidate_events)))
    stop("Candidate events require scope, track IDs, time and probability",
         call.=FALSE)
  if (!is.numeric(draws) || length(draws)!=1L ||
      !is.finite(draws) || draws<1L || draws!=floor(draws) ||
      as.double(draws)*max(1L,nrow(candidate_events))>1e6)
    stop("Invalid draws count or scenario size limit",call.=FALSE)
  if (!is.numeric(seed) || length(seed)!=1L || !is.finite(seed) ||
      seed<0 || seed>2147483647 || seed!=floor(seed))
    stop("seed must be a nonnegative 32-bit integer",call.=FALSE)
  e <- as.data.frame(candidate_events)
  for (nm in c("session_id","camera_id","track_a","track_b")) {
    if (anyNA(e[[nm]]) || any(!nzchar(trimws(as.character(e[[nm]])))))
      stop("Identity candidate scope and IDs must be nonmissing",call.=FALSE)
    e[[nm]] <- as.character(e[[nm]])
  }
  if (!is.numeric(e$at_s) || any(!is.finite(e$at_s)) ||
      !is.numeric(e$probability_swap) ||
      any(!is.finite(e$probability_swap)) ||
      any(e$probability_swap<0 | e$probability_swap>1))
    stop("Switch times must be finite and probabilities in [0,1]",
         call.=FALSE)
  if (any(e$track_a==e$track_b))
    stop("Each switch requires two distinct track labels",call.=FALSE)
  tr <- as.data.frame(tracks)
  if (nrow(e)) {
    for (i in seq_len(nrow(e))) {
      sub <- tr[tr$session_id==e$session_id[i] &
                  tr$camera_id==e$camera_id[i],,drop=FALSE]
      if (!all(c(e$track_a[i],e$track_b[i]) %in% sub$track_id) ||
          !any(sub$track_id==e$track_a[i] & sub$time_s>=e$at_s[i]) ||
          !any(sub$track_id==e$track_b[i] & sub$time_s>=e$at_s[i]))
        stop("Switch candidates must reference present future scoped fish tracks",
             call.=FALSE)
      if ("tank_id" %in% names(sub)) {
        ta <- unique(as.character(sub$tank_id[sub$track_id==e$track_a[i]]))
        tb <- unique(as.character(sub$tank_id[sub$track_id==e$track_b[i]]))
        if (length(ta)!=1L || length(tb)!=1L ||
            anyNA(c(ta,tb)) || ta!=tb)
          stop("Identity candidates cannot swap animals between tanks",
               call.=FALSE)
      }
    }
    if (nrow(e)>1L) {
      keys <- paste(e$session_id,e$camera_id,
                    sprintf("%.17g",e$at_s),sep="\r")
      for (idx in split(seq_len(nrow(e)),keys)) {
        vals <- c(e$track_a[idx],e$track_b[idx])
        if (anyDuplicated(vals))
          stop("Simultaneous switches cannot reuse a track label",call.=FALSE)
      }
    }
    e <- e[order(e$session_id,e$camera_id,e$at_s,
                 e$track_a,e$track_b),,drop=FALSE]
    rownames(e) <- NULL
  }
  had <- exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE)
  if (had) previous <- get(".Random.seed",envir=.GlobalEnv)
  on.exit({
    if (had) assign(".Random.seed",previous,envir=.GlobalEnv)
    else if (exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
      rm(".Random.seed",envir=.GlobalEnv)
  },add=TRUE)
  set.seed(as.integer(seed))
  flags <- if (nrow(e)) matrix(
    stats::runif(as.double(draws)*nrow(e)) <
      rep(e$probability_swap,each=as.integer(draws)),
    nrow=as.integer(draws),ncol=nrow(e))
  else matrix(FALSE,nrow=as.integer(draws),ncol=0L)
  structure(list(tracks=tracks,events=e,decisions=flags,
    draws=as.integer(draws),seed=as.integer(seed),
    uncertainty="discrete scenario probabilities externally assumed",
    probability_calibrated=FALSE),
    class="aqt_identity_scenarios")
}

#' Materialize one internally coherent identity-assignment scenario
#'
#' Retains original_track_id and assignment_changed flags. Scenario
#' swaps are permutations of camera/session-local labels, not cross-camera
#' re-identification. An accepted swap affects all subsequent observations
#' for the affected identities.
#'
#' @param scenarios Output from aqt_identity_switch_scenarios().
#' @param draw Scenario index, 1..draws.
#' @return Validated aqt_tracks with reassigned tracking labels.
#' @export
aqt_identity_draw <- function(scenarios,draw=1L) {
  if (!inherits(scenarios,"aqt_identity_scenarios") ||
      !inherits(scenarios$tracks,"aqt_tracks") ||
      !is.matrix(scenarios$decisions))
    stop("Expected an aqt_identity_scenarios object",call.=FALSE)
  if (!is.numeric(draw) || length(draw)!=1L || !is.finite(draw) ||
      draw<1L || draw>scenarios$draws || draw!=floor(draw))
    stop("Invalid identity scenario index",call.=FALSE)
  d <- as.data.frame(scenarios$tracks)
  d$original_track_id <- d$track_id
  chosen <- which(scenarios$decisions[as.integer(draw),])
  for (j in chosen) {
    e <- scenarios$events[j,,drop=FALSE]
    i <- which(d$session_id==e$session_id &
               d$camera_id==e$camera_id &
               d$time_s>=e$at_s &
               d$track_id %in% c(e$track_a,e$track_b))
    take_a <- i[d$track_id[i]==e$track_a]
    take_b <- i[d$track_id[i]==e$track_b]
    d$track_id[take_a] <- e$track_b
    d$track_id[take_b] <- e$track_a
  }
  d$assignment_changed <- d$track_id!=d$original_track_id
  out <- aqt_tracks(d,units=attr(scenarios$tracks,"aqt_units"),
                    coordinate_system=attr(scenarios$tracks,
                                           "aqt_coordinate_system"))
  attr(out,"aqt_identity_draw") <- as.integer(draw)
  attr(out,"aqt_identity_selected_events") <- chosen
  out
}

#' Propagate alternate fish identities into coherent swimming paths
#'
#' @param scenarios Identity uncertainty object.
#' @param max_gap_s Largest valid inter-frame movement segment.
#' @return Per-scenario path lengths and speed with exact fish ID scope.
#' @export
aqt_identity_path_sensitivity <- function(scenarios,max_gap_s=Inf) {
  if (!inherits(scenarios,"aqt_identity_scenarios"))
    stop("Expected identity scenarios",call.=FALSE)
  out <- lapply(seq_len(scenarios$draws),function(i) {
    p <- aqt_path_summary(aqt_identity_draw(scenarios,i),
                          max_gap_s=max_gap_s)
    p$draw <- i
    p
  })
  do.call(rbind,unname(out))
}

#' Propagate discrete identity assignments to event-aligned fish measures
#'
#' Computes kinematics separately for each globally consistent identity
#' scenario and then aggregates observed movement around recorded events.
#' These are measurement/identity sensitivity outputs, not independent
#' biological samples or causal estimates.
#'
#' @param scenarios Identity uncertainty object.
#' @param events Canonical event table.
#' @param outcome Kinematic variable, usually "speed".
#' @param windows Named pre/post event-relative windows.
#' @param unit_cols Identity of observation units within each session.
#' @param max_gap_s Maximum valid movement/time-weighted gap.
#' @return Long per-fish/event/epoch measurements with scenario index.
#' @export
aqt_identity_event_sensitivity <- function(
    scenarios,events,outcome="speed",
    windows=list(baseline=c(-5,0),response=c(0,5)),
    unit_cols=c("camera_id","track_id"),
    max_gap_s=Inf) {
  if (!inherits(scenarios,"aqt_identity_scenarios"))
    stop("Expected identity scenarios",call.=FALSE)
  out <- lapply(seq_len(scenarios$draws),function(i) {
    d <- aqt_kinematics(aqt_identity_draw(scenarios,i),
                        max_gap_s=max_gap_s)
    epoch <- aqt_event_epoch_summary(d,events,outcome=outcome,
       windows=windows,unit_cols=unit_cols,
       max_gap_s=max_gap_s)
    if (!nrow(epoch)) return(NULL)
    epoch$draw <- i
    epoch
  })
  out <- Filter(Negate(is.null),out)
  if (!length(out)) return(data.frame())
  answer <- do.call(rbind,unname(out))
  rownames(answer) <- NULL
  answer
}

#' Propagate identity uncertainty into independently replicated tank contrasts
#'
#' Repeats the tank-replicated before/after contrast for each discrete
#' identity scenario. One point estimate per identity draw is reported
#' with the conditional between-scenario sensitivity distribution;
#' optionally estimates *within-scenario* cluster-bootstrap percentile
#' intervals by resampling tanks rather than frames. These two variance
#' sources are kept separate and MUST NOT be interpreted as a fully
#' combined confidence interval or causal treatment effect.
#'
#' @param scenarios Identity scenario object carrying tank_id and treatment.
#' @param events Event table.
#' @param windows Named baseline and response windows.
#' @param outcome Kinematic outcome.
#' @param cluster_bootstrap_draws Bootstrap replications >=100 per identity
#'   scenario. Choose 100 for a quick demonstration.
#' @param seed Random seed for separate tank bootstrap, preserving RNG.
#' @return List with per-draw tank contrasts and identity sensitivity.
#' @export
aqt_identity_tank_sensitivity <- function(
    scenarios,events,
    windows=list(baseline=c(-5,0),response=c(0,5)),
    outcome="speed",cluster_bootstrap_draws=100L,seed=101L) {
  if (!inherits(scenarios,"aqt_identity_scenarios") ||
      !all(c("tank_id","treatment") %in% names(scenarios$tracks)))
    stop("Identity scenarios must include tank_id and treatment",call.=FALSE)
  epochs <- aqt_identity_event_sensitivity(
    scenarios,events,outcome=outcome,windows=windows,
    unit_cols=c("camera_id","track_id","tank_id","treatment"))
  if (!nrow(epochs)) stop("No estimable identity event epochs",call.=FALSE)
  results <- lapply(split(epochs,epochs$draw),function(d) {
    fit <- aqt_tank_event_contrast(d,draws=cluster_bootstrap_draws,
                                  seed=seed+as.integer(d$draw[1L]))
    data.frame(draw=as.integer(d$draw[1L]),estimate=fit$estimate,
      tank_bootstrap_lower=fit$lower,
      tank_bootstrap_upper=fit$upper,
      n_tanks_control=fit$n_tanks_control,
      n_tanks_treatment=fit$n_tanks_treatment)
  })
  per_draw <- do.call(rbind,unname(results))
  rownames(per_draw) <- NULL
  list(per_draw=per_draw,
       identity_mean=mean(per_draw$estimate),
       identity_sd=stats::sd(per_draw$estimate),
       identity_range=range(per_draw$estimate),
       identity_interval=unname(stats::quantile(per_draw$estimate,
                                  probs=c(.025,.975))),
       interpretation="conditional identity-scenario sensitivity; tank bootstrap shown separately",
       uncertainty_combined=FALSE,
       causal_identification=FALSE)
}
