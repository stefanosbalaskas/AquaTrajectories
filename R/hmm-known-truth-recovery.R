# Wave 8F: explicitly synthetic, seeded known-truth behavioural HMM
# experiments, distinct from biological fish-state validation.

#' Simulate labelled fish trajectories from a known Gaussian-state HMM
#'
#' Generates distinct independent tank/fish recording scopes, known
#' latent state labels and observed Gaussian movement outcomes. Missing
#' outcomes are explicitly unobserved; truth states remain available for
#' synthetic evaluation ONLY and must never be treated as real biology.
#' RNG state is restored upon return to avoid global side effects.
#'
#' @param n_tanks Number of independent synthetic tanks, >=4.
#' @param fish_per_tank Number of independently simulated fish per tank.
#' @param n_samples Samples per fish (>=6); not independent replicates.
#' @param state_means,state_sds Fixed Gaussian emissions for 2..5 ordered states.
#' @param transition Stochastic state transition matrix, row is source.
#' @param initial Optional initial state distribution, uniform by default.
#' @param sampling_dt_s Finite positive inter-frame interval, seconds.
#' @param missing_fraction Bernoulli independent missing outcome probability.
#' @param seed Explicit integer seed, local to this function.
#' @return aqt_hmm_known_truth data frame with provenance, truth_state
#'   and aqt_truth_model metadata; this is a synthetic simulation only.
#' @export
aqt_hmm_simulate_truth <- function(
    n_tanks=6L,fish_per_tank=2L,n_samples=100L,
    state_means=c(0,5),state_sds=c(.6,.6),
    transition=matrix(c(.9,.1,.1,.9),2,2,byrow=TRUE),
    initial=NULL,sampling_dt_s=.1,missing_fraction=0,seed=11L) {
  for (z in list(n_tanks,fish_per_tank,n_samples))
    if (!is.numeric(z) || length(z)!=1L || !is.finite(z) ||
        z<1 || z!=floor(z))
      stop("Simulation counts must be positive integers",call.=FALSE)
  if (n_tanks<4L || n_tanks>100L ||
      fish_per_tank>40L || n_samples<6L || n_samples>5000L ||
      as.double(n_tanks)*fish_per_tank*n_samples>100000)
    stop("Synthetic sample size outside supported tank/fish/frame bounds",
         call.=FALSE)
  if (!is.numeric(state_means) || any(!is.finite(state_means)) ||
      length(state_means)<2L || length(state_means)>5L ||
      any(diff(state_means)<=0))
    stop("Provide 2..5 finite strictly increasing truth state means",
         call.=FALSE)
  k <- length(state_means)
  if (!is.numeric(state_sds) || length(state_sds)!=k ||
      any(!is.finite(state_sds)) || any(state_sds<=0))
    stop("Truth Gaussian emission SDs must be positive",call.=FALSE)
  if (!is.matrix(transition) ||
      !identical(dim(transition),c(as.integer(k),as.integer(k))) ||
      !is.numeric(transition) || any(!is.finite(transition)) ||
      any(transition<0) || any(abs(rowSums(transition)-1)>1e-8))
    stop("Truth transition must be row-stochastic K-by-K",call.=FALSE)
  if (is.null(initial)) initial <- rep(1/k,k)
  if (!is.numeric(initial) || length(initial)!=k ||
      any(!is.finite(initial)) || any(initial<0) ||
      abs(sum(initial)-1)>1e-8)
    stop("Truth initial distribution must sum to one",call.=FALSE)
  if (!is.numeric(sampling_dt_s) || length(sampling_dt_s)!=1L ||
      !is.finite(sampling_dt_s) || sampling_dt_s<=0)
    stop("sampling_dt_s must be positive finite seconds",call.=FALSE)
  if (!is.numeric(missing_fraction) || length(missing_fraction)!=1L ||
      !is.finite(missing_fraction) ||
      missing_fraction<0 || missing_fraction>=.5)
    stop("missing_fraction must be between zero and .5",call.=FALSE)
  if (!is.numeric(seed) || length(seed)!=1L ||
      !is.finite(seed) || seed<0 ||
      seed>=.Machine$integer.max || seed!=floor(seed))
    stop("seed must be a finite nonnegative integer",call.=FALSE)

  had_rng <- exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE)
  if (had_rng) old_rng <- get(".Random.seed",envir=.GlobalEnv)
  on.exit({
    if (had_rng) {
      assign(".Random.seed",old_rng,envir=.GlobalEnv)
    } else if (exists(".Random.seed",envir=.GlobalEnv,
                      inherits=FALSE)) {
      rm(".Random.seed",envir=.GlobalEnv)
    }
  },add=TRUE)
  set.seed(as.integer(seed))
  records <- vector("list",as.integer(n_tanks*fish_per_tank))
  idx <- 0L
  for (tank in seq_len(as.integer(n_tanks))) {
    for (fish in seq_len(as.integer(fish_per_tank))) {
      latent <- integer(n_samples)
      latent[1L] <- sample.int(k,1L,prob=initial)
      for (t in seq.int(2L,as.integer(n_samples)))
        latent[t] <- sample.int(k,1L,
                                prob=transition[latent[t-1L],])
      values <- stats::rnorm(n_samples,
                             mean=state_means[latent],
                             sd=state_sds[latent])
      observed <- stats::runif(n_samples)>=missing_fraction
      values[!observed] <- NA_real_
      idx <- idx+1L
      records[[idx]] <- data.frame(
        session_id=sprintf("S%03d",tank),
        camera_id="SIM_TOP",
        track_id=sprintf("F%03d",fish),
        tank_id=sprintf("T%03d",tank),
        time_s=(seq_len(n_samples)-1L)*sampling_dt_s,
        speed=values,observed=observed,
        truth_state=latent,
        stringsAsFactors=FALSE)
    }
  }
  result <- do.call(rbind,records)
  rownames(result) <- NULL
  class(result) <- c("aqt_hmm_known_truth","data.frame")
  attr(result,"aqt_truth_model") <- list(
    state_means=state_means,state_sds=state_sds,
    transition=transition,initial=initial,
    sampling_dt_s=sampling_dt_s,seed=as.integer(seed),
    missing_fraction=missing_fraction,
    synthetic_only=TRUE,biological_state_certified=FALSE)
  result
}

#' Audit Gaussian HMM transition and state recovery on unseen synthetic tanks
#'
#' Fits Wave 8E's fixed-emission transition model on selected synthetic
#' tanks, then predicts previously unseen simulation tanks. The truth
#' emission parameters are supplied to the fitting stage by design.
#' This benchmark checks code/estimation recoverability, NOT real fish
#' state calibration, detection uncertainty or independent animal welfare.
#'
#' @param simulated aqt_hmm_known_truth from aqt_hmm_simulate_truth.
#' @param training_tanks Distinct tank IDs for training; >=2 training and
#'   >=2 other strictly heldout tank IDs required.
#' @param min_segment Minimum consecutive observed points.
#' @param max_gap_s Default is 1.01 times the simulated sample interval.
#' @param max_iter,tol,prior Estimation settings for Wave 8E.
#' @return aqt_hmm_recovery_audit with truth/estimated parameters,
#'   heldout accuracy/confusion and conditional predictive likelihood.
#' @export
aqt_hmm_recovery_audit <- function(
    simulated,training_tanks,min_segment=3L,max_gap_s=NULL,
    max_iter=150L,tol=1e-6,prior=.01) {
  if (!inherits(simulated,"aqt_hmm_known_truth") ||
      !is.data.frame(simulated) ||
      !all(c("session_id","camera_id","track_id","tank_id",
             "time_s","speed","observed","truth_state") %in%
           names(simulated)))
    stop("Expected aqt_hmm_known_truth simulation",call.=FALSE)
  truth <- attr(simulated,"aqt_truth_model")
  if (!is.list(truth) || !identical(truth$synthetic_only,TRUE))
    stop("Synthetic truth metadata required",call.=FALSE)
  all_tanks <- unique(as.character(simulated$tank_id))
  if (!is.character(training_tanks) || length(training_tanks)<2L ||
      anyNA(training_tanks) ||
      any(!nzchar(trimws(training_tanks))) ||
      anyDuplicated(training_tanks) ||
      !all(training_tanks %in% all_tanks) ||
      length(setdiff(all_tanks,training_tanks))<2L)
    stop("Require >=2 distinct known training and heldout tanks",
         call.=FALSE)
  if (is.null(max_gap_s))
    max_gap_s <- 1.01*truth$sampling_dt_s
  train <- as.data.frame(simulated[
    simulated$tank_id %in% training_tanks,,drop=FALSE])
  test <- as.data.frame(simulated[
    !simulated$tank_id %in% training_tanks,,drop=FALSE])
  fit <- aqt_hmm_transition_fit(
    train,outcome="speed",
    state_means=truth$state_means,state_sds=truth$state_sds,
    max_gap_s=max_gap_s,min_segment=min_segment,
    max_iter=max_iter,tol=tol,prior=prior)
  holdout <- aqt_hmm_holdout_score(
    test,fit,require_disjoint_tanks=TRUE)
  d <- aqt_hmm_decode(
    test,outcome="speed",
    state_means=fit$state_means,state_sds=fit$state_sds,
    transition=fit$transition,initial=fit$initial,
    max_gap_s=max_gap_s,min_segment=min_segment)
  usable <- which(!is.na(d$hmm_state))
  if (!length(usable))
    stop("No classified synthetic heldout states",call.=FALSE)
  k <- length(truth$state_means)
  if (anyNA(d$truth_state[usable]) ||
      any(!(d$truth_state[usable] %in% seq_len(k))))
    stop("Heldout latent truth labels must be complete and valid",
         call.=FALSE)
  confusion <- table(
    truth=factor(d$truth_state[usable],levels=seq_len(k)),
    decoded=factor(d$hmm_state[usable],levels=seq_len(k)))
  recall <- diag(confusion)/rowSums(confusion)
  recall[rowSums(confusion)==0L] <- NA_real_
  structure(list(
    train_tanks=training_tanks,
    holdout_tanks=setdiff(all_tanks,training_tanks),
    n_training_tanks=length(training_tanks),
    n_holdout_tanks=length(setdiff(all_tanks,training_tanks)),
    n_training_fish=fit$n_training_fish,
    n_heldout_modelled=length(usable),
    n_heldout_missing_or_unsupported=
      nrow(d)-length(usable),
    truth_transition=truth$transition,
    fitted_transition=fit$transition,
    transition_mean_abs_error=
      mean(abs(fit$transition-truth$transition)),
    transition_max_abs_error=
      max(abs(fit$transition-truth$transition)),
    truth_initial=truth$initial,
    fitted_initial=fit$initial,
    initial_mean_abs_error=mean(abs(fit$initial-truth$initial)),
    heldout_viterbi_truth_accuracy=
      mean(d$hmm_state[usable]==d$truth_state[usable]),
    heldout_state_recall=recall,
    heldout_confusion=confusion,
    heldout_total_loglik=holdout$total_loglik,
    heldout_mean_loglik_per_sample=
      holdout$mean_loglik_per_sample,
    em_converged=fit$converged,
    em_iterations=fit$iterations,
    training_fit=fit,
    holdout_score=holdout,
    benchmark_scope="seeded known-truth synthetic Gaussian fish sequences only",
    real_underwater_validation=FALSE,
    biological_welfare_certified=FALSE,
    experimental_treatment_inference=FALSE),
    class="aqt_hmm_recovery_audit")
}
