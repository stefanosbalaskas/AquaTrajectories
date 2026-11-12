# Wave 8G: conditional HMM state occupancy around externally logged
# experimental events. Independent TANKS, not fish/frames, are treatment units.

#' Aggregate event-aligned posterior fish states to independent tanks
#'
#' Requires aqt_hmm_states (Wave 8D), externally logged one-event-per-
#' session timestamps and a valid between-tank two-arm study design.
#' Computes one baseline and response posterior-state mean per fish,
#' rejecting all incomplete fish epochs, then equal-weights complete fish
#' within each tank. Returns a tank-by-epoch frame compatible with
#' aqt_tank_event_contrast; the same fish must contribute to both epochs.
#' Uses sample-weighted observed posterior probabilities, not estimated
#' dwell-time proportions, welfare measures or independent frame tests.
#'
#' @param decoded aqt_hmm_states from conditional decoding.
#' @param events Event log, one recorded event per recording session.
#' @param state Integer 1..K index of target descriptive HMM state.
#' @param baseline_window_s Pre-event relative seconds [start,end).
#' @param response_window_s Post-event relative seconds [start,end].
#' @param min_points Minimum finite decoded posterior observations in
#'   each fish/epoch; incomplete fish raises an explicit error.
#' @param treatment_levels Exactly c(control,treatment) arm labels.
#' @return aqt_hmm_tank_epochs data frame with tank_id,treatment,epoch,
#'   value and n_fish, plus fish-level QC and design-audit attributes.
#' @export
aqt_hmm_event_tank_epochs <- function(
    decoded,events,state=2L,
    baseline_window_s=c(-10,0),response_window_s=c(0,10),
    min_points=3L,treatment_levels=c("control","treatment")) {
  required <- c("session_id","camera_id","track_id","tank_id",
                "treatment","time_s","hmm_state")
  if (!inherits(decoded,"aqt_hmm_states") ||
      !is.data.frame(decoded) || !nrow(decoded) ||
      !all(required %in% names(decoded)))
    stop("Expected decoded HMM fish states with tank and treatment",
         call.=FALSE)
  model <- attr(decoded,"aqt_hmm_model")
  if (!is.list(model) || is.null(model$labels))
    stop("Missing Gaussian HMM state metadata",call.=FALSE)
  k <- length(model$labels)
  if (!is.numeric(state) || length(state)!=1L ||
      !is.finite(state) || state!=floor(state) ||
      state<1L || state>k)
    stop("state must be a valid integer HMM state index",call.=FALSE)
  pcol <- paste0("hmm_p",state)
  if (!pcol %in% names(decoded) ||
      !is.numeric(decoded[[pcol]]) ||
      any(is.infinite(decoded[[pcol]])) ||
      any(decoded[[pcol]]<0 | decoded[[pcol]]>1,na.rm=TRUE))
    stop("Expected finite-or-missing posterior probability for selected state",
         call.=FALSE)
  for (w in list(baseline_window_s,response_window_s))
    if (!is.numeric(w) || length(w)!=2L ||
        any(!is.finite(w)) || w[1L]>=w[2L])
      stop("Event windows require finite increasing seconds",call.=FALSE)
  if (baseline_window_s[2L]>0 || response_window_s[1L]<0 ||
      baseline_window_s[2L]>response_window_s[1L])
    stop("Baseline must precede event onset and response must follow",
         call.=FALSE)
  if (!is.numeric(min_points) || length(min_points)!=1L ||
      !is.finite(min_points) || min_points<2L ||
      min_points!=floor(min_points))
    stop("min_points must be an integer >=2",call.=FALSE)
  if (!is.character(treatment_levels) ||
      length(treatment_levels)!=2L ||
      anyNA(treatment_levels) ||
      any(!nzchar(trimws(treatment_levels))) ||
      anyDuplicated(treatment_levels))
    stop("Exactly two distinct treatment labels required",call.=FALSE)
  design <- aqt_design_audit(decoded,"treatment","tank_id")
  if (!setequal(design$treatment,treatment_levels) ||
      any(design$n_tanks<2L))
    stop("Require >=2 independent tanks per declared treatment group",
         call.=FALSE)
  d <- as.data.frame(decoded)
  for (id in required[c(1,2,3,4,5)]) {
    z <- as.character(d[[id]])
    if (anyNA(z) || any(!nzchar(trimws(z))))
      stop("HMM experimental fish/tank identities must be complete",
           call.=FALSE)
  }
  if (!is.numeric(d$time_s) || any(!is.finite(d$time_s)))
    stop("HMM timestamps must be finite numeric seconds",
         call.=FALSE)
  # One session per independently treated tank; repeated events,
  # crossover and multi-session animal reuse need another design.
  for (idx in split(seq_len(nrow(d)),as.character(d$tank_id)))
    if (length(unique(as.character(d$session_id[idx])))!=1L)
      stop("This design requires one recording session per tank",
           call.=FALSE)
  e <- aqt_event_table(events)
  if (anyDuplicated(e$session_id) ||
      !setequal(as.character(e$session_id),
                as.character(unique(d$session_id))))
    stop("Require one externally logged event per fish recording session",
         call.=FALSE)
  windows <- list(
    baseline=baseline_window_s,response=response_window_s)
  fish_epochs <- aqt_event_epoch_summary(
    d,e,outcome=pcol,windows=windows,
    unit_cols=c("tank_id","treatment","camera_id","track_id"),
    estimator="sample_mean",min_points=min_points)
  if (!nrow(fish_epochs))
    stop("No observed fish state epochs in declared event windows",
         call.=FALSE)
  fish_ids <- c("session_id","tank_id","camera_id","track_id")
  expected <- unique(do.call(paste,c(d[fish_ids],list(sep="\r"))))
  actual <- unique(do.call(paste,c(fish_epochs[fish_ids],
                                  list(sep="\r"))))
  if (!setequal(expected,actual))
    stop("Every scoped fish must have both event epochs",call.=FALSE)
  keys <- do.call(paste,c(fish_epochs[fish_ids],list(sep="\r")))
  for (idx in split(seq_len(nrow(fish_epochs)),keys)) {
    z <- fish_epochs[idx,,drop=FALSE]
    if (nrow(z)!=2L ||
        !setequal(as.character(z$epoch),c("baseline","response")) ||
        any(!is.finite(z$value)) ||
        any(z$n_valid<min_points))
      stop("Each fish requires supported baseline and response epochs",
           call.=FALSE)
  }
  rows <- list()
  counter <- 0L
  for (tank in sort(unique(as.character(fish_epochs$tank_id)))) {
    ft <- fish_epochs[as.character(fish_epochs$tank_id)==tank,,
                      drop=FALSE]
    treatments <- unique(as.character(ft$treatment))
    if (length(treatments)!=1L)
      stop("Conflicting fish treatment within tank",call.=FALSE)
    for (epoch in c("baseline","response")) {
      x <- ft[ft$epoch==epoch,,drop=FALSE]
      counter <- counter+1L
      rows[[counter]] <- data.frame(
        tank_id=tank,treatment=treatments,
        epoch=epoch,value=mean(x$value),
        n_fish=nrow(x),
        n_valid_fish_samples=sum(x$n_valid),
        n_total_fish_samples=sum(x$n_samples),
        state_index=as.integer(state),
        state_label=model$labels[state],
        stringsAsFactors=FALSE)
    }
  }
  result <- do.call(rbind,rows)
  rownames(result) <- NULL
  class(result) <- c("aqt_hmm_tank_epochs","data.frame")
  attr(result,"aqt_hmm_fish_epochs") <- fish_epochs
  attr(result,"aqt_hmm_design_audit") <- design
  attr(result,"aqt_hmm_windows") <- windows
  attr(result,"aqt_sample_weighted") <- TRUE
  attr(result,"aqt_experimental_unit") <- "tank"
  attr(result,"aqt_hmm_biological_state_certified") <- FALSE
  result
}

#' Compare two-arm fish HMM event changes with tank-level resampling
#'
#' Reuses the existing aqt_tank_event_contrast() tank-bootstrap contract,
#' after the strict per-fish and per-tank posterior aggregation above.
#' Reports treated-minus-control differences in within-tank change of
#' sample-averaged HMM posterior probability. Independent tank bootstrap
#' is a sensitivity interval, not calibrated coverage or causal evidence.
#'
#' @param epochs aqt_hmm_tank_epochs from aqt_hmm_event_tank_epochs.
#' @param treatment_levels Two ordered treatment labels.
#' @param draws,level,seed Tank-level bootstrap parameters.
#' @return aqt_hmm_tank_event_contrast, retaining fish QC and original
#'   tank-level resampling estimates and explicit scientific limitations.
#' @export
aqt_hmm_tank_event_contrast <- function(
    epochs,treatment_levels=c("control","treatment"),
    draws=499L,level=.95,seed=7L) {
  if (!inherits(epochs,"aqt_hmm_tank_epochs") ||
      !all(c("tank_id","treatment","epoch","value","state_index") %in%
           names(epochs)) ||
      !identical(attr(epochs,"aqt_experimental_unit"),"tank"))
    stop("Expected prepared HMM posterior tank event epochs",
         call.=FALSE)
  if (anyDuplicated(paste(epochs$tank_id,epochs$epoch,sep="\r")))
    stop("Duplicate tank by epoch in HMM event contrast",
         call.=FALSE)
  result <- aqt_tank_event_contrast(
    as.data.frame(epochs),treatment_levels=treatment_levels,
    baseline="baseline",response="response",
    draws=draws,level=level,seed=seed)
  result$state_index <- unique(epochs$state_index)
  result$state_label <- unique(as.character(epochs$state_label))
  result$fish_epoch_audit <- attr(epochs,"aqt_hmm_fish_epochs")
  result$design_audit <- attr(epochs,"aqt_hmm_design_audit")
  result$posterior_sample_weighted <- TRUE
  result$individual_fish_or_video_frames_are_experimental_units <- FALSE
  result$biological_welfare_certified <- FALSE
  result$causal_identification <- FALSE
  class(result) <- c("aqt_hmm_tank_event_contrast","list")
  result
}
