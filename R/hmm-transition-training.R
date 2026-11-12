# Wave 8E: fixed-emission Gaussian HMM transition/initial fitting.
# Observation-conditioned EM is descriptive, not a welfare diagnosis.

#' Estimate HMM transition dynamics while holding Gaussian emissions fixed
#'
#' Baum-Welch expected transition counts pooled across separately observed
#' fish segments. Gaussian state means and SDs are externally specified,
#' NOT fitted. Every fish/session/camera/tank boundary, missing frame and
#' large time gap is a distinct sequence. A positive symmetric Dirichlet
#' pseudocount regularizes each transition row and the initial state
#' distribution. Results describe steps between recorded observations,
#' not elapsed-time transition rates or independent-tank treatment effects.
#'
#' @param data Fish outcome data accepted by aqt_hmm_decode.
#' @param outcome Numeric behavioural outcome name.
#' @param state_means Strictly increasing supplied Gaussian means.
#' @param state_sds Strictly positive supplied Gaussian standard deviations.
#' @param start_transition Optional K-by-K starting row-stochastic matrix.
#' @param start_initial Optional starting initial state probability vector.
#' @param max_gap_s,max_iter,min_segment,tol Explicit segment and EM controls.
#' @param prior Positive Dirichlet pseudocount per transition and state.
#' @return aqt_hmm_transition_fit with learned transition/initial, fixed
#'   emissions, likelihood history, training scopes and convergence audit.
#' @export
aqt_hmm_transition_fit <- function(
    data,outcome="speed",state_means,state_sds,
    start_transition=NULL,start_initial=NULL,
    max_gap_s=.5,min_segment=3L,max_iter=200L,
    tol=1e-7,prior=.01) {
  if (!is.numeric(state_means) || any(!is.finite(state_means)) ||
      length(state_means)<2L || length(state_means)>5L ||
      any(diff(state_means)<=0))
    stop("Provide 2..5 increasing fixed Gaussian emission means",
         call.=FALSE)
  k <- length(state_means)
  if (!is.numeric(state_sds) || length(state_sds)!=k ||
      any(!is.finite(state_sds)) || any(state_sds<=0))
    stop("State emission SDs must be positive and fixed",call.=FALSE)
  if (!is.numeric(max_iter) || length(max_iter)!=1L ||
      !is.finite(max_iter) || max_iter<2L ||
      max_iter!=floor(max_iter) || max_iter>2000L)
    stop("max_iter must be an integer between 2 and 2000",call.=FALSE)
  if (!is.numeric(tol) || length(tol)!=1L ||
      !is.finite(tol) || tol<=0)
    stop("tol must be strictly positive finite",call.=FALSE)
  if (!is.numeric(prior) || length(prior)!=1L ||
      !is.finite(prior) || prior<=0)
    stop("prior must be a positive Dirichlet pseudocount",
         call.=FALSE)
  if (is.null(start_transition)) {
    start_transition <- matrix((1-.9)/(k-1),k,k)
    diag(start_transition) <- .9
  }
  if (is.null(start_initial)) start_initial <- rep(1/k,k)
  if (!is.matrix(start_transition) ||
      !identical(dim(start_transition),c(as.integer(k),as.integer(k))) ||
      !is.numeric(start_transition) ||
      any(!is.finite(start_transition)) ||
      any(start_transition<0) ||
      any(abs(rowSums(start_transition)-1)>1e-8))
    stop("start_transition must be row-stochastic K-by-K",
         call.=FALSE)
  if (!is.numeric(start_initial) || length(start_initial)!=k ||
      any(!is.finite(start_initial)) ||
      any(start_initial<0) ||
      abs(sum(start_initial)-1)>1e-8)
    stop("start_initial must be a state probability vector",
         call.=FALSE)
  d <- .aqt_hmm_prepare(data,outcome,max_gap_s,min_segment)
  seg <- sort(unique(stats::na.omit(d$hmm_segment)))
  if (length(seg)<2L)
    stop("Need >=2 independently segmented observed fish sequences",
         call.=FALSE)
  ids <- c("session_id","camera_id","track_id",
           intersect("tank_id",names(d)))
  segment_rows <- lapply(seg,function(s) which(d$hmm_segment==s))
  training_scope <- unique(do.call(paste,c(d[ids],list(sep="\r"))))
  if (length(training_scope)<2L)
    stop("HMM transition fitting requires >=2 distinct scoped fish",
         call.=FALSE)
  transition <- start_transition
  initial <- start_initial
  history <- numeric()
  converged <- FALSE
  last_expected <- matrix(0,k,k)
  last_occ <- numeric(k)
  for (iteration in seq_len(as.integer(max_iter))) {
    counts <- matrix(0,k,k)
    initial_counts <- numeric(k)
    occupancy <- numeric(k)
    total_ll <- 0
    for (idx in segment_rows) {
      y <- d$hmm_value[idx]
      calc <- .aqt_hmm_segment_decode(
        y,state_means,state_sds,transition,initial)
      total_ll <- total_ll+calc$loglik
      initial_counts <- initial_counts+calc$posterior[1L,]
      occupancy <- occupancy+colSums(calc$posterior)
      n <- length(y)
      if (n>1L) for (t in seq_len(n-1L)) {
        joint <- outer(
          calc$logalpha[t,],
          calc$logemission[t+1L,]+calc$logbeta[t+1L,],"+")+
          log(transition)
        log_denom <- .aqt_hmm_lse(as.vector(joint))
        if (!is.finite(log_denom))
          stop("Nonfinite HMM pairwise posterior",call.=FALSE)
        counts <- counts+exp(joint-log_denom)
      }
    }
    history <- c(history,total_ll)
    smoothed <- counts+prior
    new_transition <- smoothed/rowSums(smoothed)
    new_initial <- (initial_counts+prior)/
      (sum(initial_counts)+k*prior)
    change <- max(abs(new_transition-transition),
                  abs(new_initial-initial))
    transition <- new_transition
    initial <- new_initial
    last_expected <- counts
    last_occ <- occupancy
    if (change<tol) {
      converged <- TRUE
      break
    }
  }
  final_ll <- sum(vapply(segment_rows,function(idx)
    .aqt_hmm_segment_decode(d$hmm_value[idx],state_means,
                            state_sds,transition,initial)$loglik,
    numeric(1)))
  history <- c(history,final_ll)
  structure(list(
    state_means=state_means,state_sds=state_sds,
    transition=transition,initial=initial,
    outcome=outcome,max_gap_s=max_gap_s,min_segment=min_segment,
    prior=prior,tol=tol,max_iter=as.integer(max_iter),
    iterations=length(history)-1L,converged=converged,
    loglik=final_ll,loglik_history=history,
    expected_transition_counts=last_expected,
    expected_state_observations=last_occ,
    n_sequences=length(seg),
    n_modelled_samples=sum(!is.na(d$hmm_segment)),
    n_training_fish=length(training_scope),
    training_scope=training_scope,
    has_tank_id="tank_id" %in% names(d),
    training_tanks=if("tank_id" %in% names(d))
      unique(as.character(d$tank_id)) else character(),
    emission_parameters_estimated=FALSE,
    transition_parameters_estimated=TRUE,
    tank_treatment_inference=FALSE,
    welfare_certified=FALSE),
    class="aqt_hmm_transition_fit")
}

#' Score held-out fish under a fixed trained HMM without leakage
#'
#' Applies fixed state emissions and learned transitions to new fish
#' sequences. Rejects any overlapping scoped fish, and by default
#' requires nonoverlapping independent tank IDs. Returns the total and
#' mean per-modelled-sample conditional log likelihood. This is an
#' observed-data predictive score, NOT proof of physiological state
#' accuracy, confidence-interval coverage or causal generalization.
#'
#' @param data Previously unseen fish outcome frame.
#' @param fitted aqt_hmm_transition_fit, trained on disjoint data.
#' @param require_disjoint_tanks Require tank_id on both training and
#'   test data, and prohibit any training/test tank overlap (default).
#' @return aqt_hmm_holdout_score with sample support and leakage audit.
#' @export
aqt_hmm_holdout_score <- function(
    data,fitted,require_disjoint_tanks=TRUE) {
  if (!inherits(fitted,"aqt_hmm_transition_fit"))
    stop("Expected aqt_hmm_transition_fit",call.=FALSE)
  if (!is.logical(require_disjoint_tanks) ||
      length(require_disjoint_tanks)!=1L ||
      is.na(require_disjoint_tanks))
    stop("require_disjoint_tanks must be single logical",call.=FALSE)
  if (!is.data.frame(data) || !nrow(data))
    stop("Expected nonempty heldout fish observations",call.=FALSE)
  has_tank <- "tank_id" %in% names(data)
  if (!identical(has_tank,fitted$has_tank_id))
    stop("Heldout tank_id schema must match training",call.=FALSE)
  if (require_disjoint_tanks && !has_tank)
    stop("Independent-tank holdout requires tank_id in both datasets",
         call.=FALSE)
  ids <- c("session_id","camera_id","track_id",
           if (has_tank) "tank_id")
  if (!all(ids %in% names(data)))
    stop("Heldout fish scope fields are missing",call.=FALSE)
  scope <- unique(do.call(paste,c(data[ids],list(sep="\r"))))
  if (length(intersect(scope,fitted$training_scope)))
    stop("Heldout fish scope overlaps training data",call.=FALSE)
  if (require_disjoint_tanks &&
      length(intersect(as.character(data$tank_id),
                       fitted$training_tanks)))
    stop("Heldout experimental tanks overlap training tanks",
         call.=FALSE)
  d <- aqt_hmm_decode(
    data,outcome=fitted$outcome,
    state_means=fitted$state_means,state_sds=fitted$state_sds,
    transition=fitted$transition,initial=fitted$initial,
    max_gap_s=fitted$max_gap_s,
    min_segment=fitted$min_segment)
  n_modelled <- sum(!is.na(d$hmm_state))
  score <- attr(d,"aqt_hmm_total_loglik")
  structure(list(
    total_loglik=score,
    mean_loglik_per_sample=score/n_modelled,
    n_input=nrow(d),n_modelled=n_modelled,
    n_missing_or_unsupported=nrow(d)-n_modelled,
    n_sequences=nrow(attr(d,"aqt_hmm_segment_loglik")),
    independent_tank_holdout=require_disjoint_tanks,
    no_scoped_fish_overlap=TRUE,
    n_holdout_tanks=if (has_tank)
      length(unique(as.character(data$tank_id))) else NA_integer_,
    state_truth_certified=FALSE,
    calibration_certified=FALSE),
    class="aqt_hmm_holdout_score")
}
