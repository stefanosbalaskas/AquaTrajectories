# Animal–Computer Interaction closed-loop trial telemetry.
# These functions measure system performance and observed opportunity,
# NOT animal agency, preference, welfare or causal reinforcement.

#' Validate externally annotated fish-device interaction trials
#'
#' One row records one declared fish opportunity and its optional
#' observed action, detector trigger, control command, physical actuator
#' observation and verified fish response. All clocks must have been
#' synchronized into the same session time base before use.
#'
#' Missing action with a detection means a PROPOSED false trigger,
#' conditional on the annotation's accuracy; it is not discarded.
#' Downstream device stages may not appear before their predecessor.
#'
#' @param data Frame with session_id, trial_id, fish_id, opportunity_s,
#'   end_s, action_s, detection_s, command_s, actuator_s, response_s.
#'   Absent timestamps are numeric NA. Optional tank_id and condition.
#' @return aqt_aci_trials with validated event sequences and latency fields.
#' @export
aqt_aci_trials <- function(data) {
  required <- c("session_id","trial_id","fish_id","opportunity_s",
                "end_s","action_s","detection_s","command_s",
                "actuator_s","response_s")
  if (!is.data.frame(data) || !nrow(data) ||
      !all(required %in% names(data)))
    stop("Expected nonempty ACI opportunity and device-stage log",
         call.=FALSE)
  x <- as.data.frame(data)
  ids <- c("session_id","trial_id","fish_id",
           intersect(c("tank_id","condition"),names(x)))
  for (nm in ids) {
    v <- as.character(x[[nm]])
    if (anyNA(v) || any(!nzchar(trimws(v))))
      stop("Missing trial, fish or experimental scope",call.=FALSE)
    x[[nm]] <- v
  }
  key <- paste(x$session_id,x$fish_id,x$trial_id,sep="\r")
  if (anyDuplicated(key))
    stop("Duplicate animal opportunity within scoped trial",call.=FALSE)
  time_cols <- required[4:10]
  if (!all(vapply(x[time_cols],is.numeric,logical(1L))) ||
      any(vapply(x[time_cols],function(z)any(is.infinite(z)),
                 logical(1L))))
    stop("Device and fish event times must be numeric and non-infinite",
         call.=FALSE)
  if (any(!is.finite(x$opportunity_s)) ||
      any(!is.finite(x$end_s)) ||
      any(x$end_s<=x$opportunity_s))
    stop("Each opportunity needs a finite positive time window",call.=FALSE)
  for (nm in time_cols[3:7]) {
    v <- x[[nm]]
    if (any(!is.na(v) &
            (v<x$opportunity_s | v>x$end_s)))
      stop("Action/device stages must occur within the declared trial window",
           call.=FALSE)
  }
  pairs <- list(c("action_s","detection_s"),
                c("detection_s","command_s"),
                c("command_s","actuator_s"),
                c("actuator_s","response_s"))
  # The first pair allows a detection when no action was annotated
  # (a potential false detection). All subsequent stages require
  # their immediate predecessor.
  for (i in seq_along(pairs)) {
    prev <- x[[pairs[[i]][1L]]]
    next_stage <- x[[pairs[[i]][2L]]]
    if (i>=2L && any(is.na(prev) & !is.na(next_stage)))
      stop("Device stage exists without its required predecessor",
           call.=FALSE)
    if (any(!is.na(prev) & !is.na(next_stage) &
            next_stage<prev))
      stop("Non-monotone animal/device event timeline",call.=FALSE)
  }
  x$has_action <- !is.na(x$action_s)
  x$has_detection <- !is.na(x$detection_s)
  x$has_actuation <- !is.na(x$actuator_s)
  x$false_trigger <- !x$has_action & x$has_detection
  x$false_actuation <- !x$has_action & x$has_actuation
  x$detector_latency_s <- x$detection_s-x$action_s
  x$controller_latency_s <- x$command_s-x$detection_s
  x$actuator_latency_s <- x$actuator_s-x$command_s
  x$end_to_end_s <- x$actuator_s-x$action_s
  for (nm in c("detector_latency_s","controller_latency_s",
               "actuator_latency_s","end_to_end_s")) {
    x[[nm]][!is.finite(x[[nm]])] <- NA_real_
  }
  class(x) <- c("aqt_aci_trials","data.frame")
  attr(x,"annotation_certified") <- FALSE
  attr(x,"clock_synchronization_certified") <- FALSE
  attr(x,"animal_agency_claimed") <- FALSE
  x
}

#' Summarize animal-action to physical-device contingency by trial group
#'
#' Reports P(observed actuation | verified action), P(observed
#' actuation | no annotated action), and their difference. This
#' contingency is DESCRIPTIVE, not proof of animal understanding,
#' preference, agency, a learned causal relationship or welfare.
#' Counts use opportunities, not fish-camera video frames.
#'
#' @param trials Output of aqt_aci_trials().
#' @param group_cols Grouping columns such as session_id, fish_id or
#'   condition. Session_id must always be included.
#' @return Per-group counts, detector and actuator reliability and
#'   descriptive contingency differences.
#' @export
aqt_aci_loop_metrics <- function(trials,
                                 group_cols=c("session_id","fish_id")) {
  if (!inherits(trials,"aqt_aci_trials"))
    stop("Expected aqt_aci_trials log",call.=FALSE)
  if (!is.character(group_cols) || !length(group_cols) ||
      !"session_id" %in% group_cols || anyDuplicated(group_cols) ||
      !all(group_cols %in% names(trials)))
    stop("group_cols must include session_id and existing unique columns",
         call.=FALSE)
  keys <- do.call(paste,c(lapply(trials[group_cols],as.character),
                          list(sep="\r")))
  records <- lapply(split(seq_len(nrow(trials)),keys),function(i) {
    d <- trials[i,,drop=FALSE]
    action <- d$has_action
    detected <- d$has_detection
    actuator <- d$has_actuation
    n_true <- sum(action)
    n_false <- sum(!action)
    yes <- sum(action & actuator)
    false <- sum(!action & actuator)
    result <- data.frame(n_opportunities=nrow(d),
      n_actions=n_true,n_no_action=n_false,
      n_true_detections=sum(action & detected),
      n_missed_detections=sum(action & !detected),
      n_false_detections=sum(!action & detected),
      n_true_activations=yes,n_false_activations=false,
      p_activation_given_action=if(n_true)yes/n_true else NA_real_,
      p_activation_given_no_action=if(n_false)false/n_false else NA_real_,
      contingency_difference=if(n_true && n_false)
        yes/n_true-false/n_false else NA_real_,
      annotation_certified=FALSE,
      causal_agency_inference=FALSE)
    for (col in group_cols)result[[col]] <- d[[col]][1L]
    result
  })
  out <- do.call(rbind,unname(records))
  rownames(out) <- NULL
  out
}

#' Summarize measured fish-device loop latency without timing imputation
#'
#' Means and medians are computed only for observed timestamp pairs;
#' the number with complete end-to-end records is always reported.
#' Sessions must be grouped explicitly; a null stage is NOT assigned
#' latency zero.
#'
#' @param trials aqt_aci_trials.
#' @param group_cols Grouping columns including session_id.
#' @return Per-group stage latency medians and complete-trial fractions.
#' @export
aqt_aci_latency_summary <- function(trials,
                                    group_cols=c("session_id","fish_id")) {
  if (!inherits(trials,"aqt_aci_trials"))
    stop("Expected aqt_aci_trials log",call.=FALSE)
  if (!is.character(group_cols) || !length(group_cols) ||
      !"session_id" %in% group_cols || anyDuplicated(group_cols) ||
      !all(group_cols %in% names(trials)))
    stop("group_cols must include session_id and existing unique columns",
         call.=FALSE)
  keys <- do.call(paste,c(lapply(trials[group_cols],as.character),
                          list(sep="\r")))
  records <- lapply(split(seq_len(nrow(trials)),keys),function(i) {
    d <- trials[i,,drop=FALSE]
    med <- function(v) if(any(is.finite(v)))
      stats::median(v[is.finite(v)]) else NA_real_
    completed <- is.finite(d$end_to_end_s)
    rec <- data.frame(
      n_opportunities=nrow(d),n_actions=sum(d$has_action),
      n_complete=sum(completed),
      complete_fraction=mean(completed),
      detector_median_s=med(d$detector_latency_s),
      controller_median_s=med(d$controller_latency_s),
      actuator_median_s=med(d$actuator_latency_s),
      end_to_end_median_s=med(d$end_to_end_s),
      clock_synchronization_certified=FALSE)
    for (col in group_cols)rec[[col]] <- d[[col]][1L]
    rec
  })
  out <- do.call(rbind,unname(records))
  rownames(out) <- NULL
  out
}
