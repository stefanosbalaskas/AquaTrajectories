# Wave 8D: conditional univariate Gaussian HMM for observed fish behaviour.
# This decoder is NOT trained on a species, a welfare diagnosis, or a
# measurement-error-calibrated biological state classifier.

.aqt_hmm_prepare <- function(data,outcome,max_gap_s,min_segment) {
  req <- c("session_id","camera_id","track_id","time_s",outcome)
  if (!is.data.frame(data) || !nrow(data) ||
      !all(req %in% names(data)))
    stop("Expected nonempty scoped fish outcome table",call.=FALSE)
  if (!is.character(outcome) || length(outcome)!=1L ||
      is.na(outcome) || !nzchar(outcome) ||
      !is.numeric(data[[outcome]]) ||
      !is.numeric(data$time_s) ||
      any(!is.finite(data$time_s)) ||
      any(is.infinite(data[[outcome]])))
    stop("HMM outcome must be numeric without infinities and time_s finite",
         call.=FALSE)
  if (!is.numeric(max_gap_s) || length(max_gap_s)!=1L ||
      !is.finite(max_gap_s) || max_gap_s<=0)
    stop("max_gap_s must be finite positive seconds",call.=FALSE)
  if (!is.numeric(min_segment) || length(min_segment)!=1L ||
      !is.finite(min_segment) || min_segment<2 ||
      min_segment!=floor(min_segment))
    stop("min_segment must be an integer >=2",call.=FALSE)
  ids <- c("session_id","camera_id","track_id",
           intersect("tank_id",names(data)))
  for (nm in c(ids,intersect("treatment",names(data)))) {
    v <- as.character(data[[nm]])
    if (anyNA(v) || any(!nzchar(trimws(v))))
      stop("HMM fish, tank and treatment IDs must be complete",call.=FALSE)
  }
  if ("observed" %in% names(data) &&
      (!is.logical(data$observed) || anyNA(data$observed)))
    stop("observed must be a complete logical observation flag",
         call.=FALSE)
  if (any(c("hmm_state","hmm_state_label","hmm_entropy",
            "hmm_segment","hmm_usable","hmm_value") %in% names(data)) ||
      any(grepl("^hmm_p[0-9]+$",names(data))))
    stop("Existing HMM output columns must not be overwritten",
         call.=FALSE)
  d <- as.data.frame(data)
  d <- d[do.call(order,d[c(ids,"time_s")]),,drop=FALSE]
  rownames(d) <- NULL
  valid <- is.finite(d[[outcome]])
  if ("observed" %in% names(d)) valid <- valid & d$observed
  key <- do.call(paste,c(d[ids],list(sep="\r")))
  segments <- rep(NA_integer_,nrow(d))
  segment_count <- 0L
  for (idx in split(seq_len(nrow(d)),key)) {
    t <- d$time_s[idx]
    if (any(diff(t)<=0))
      stop("Duplicate/nonincreasing timestamps within scoped fish",
           call.=FALSE)
    if ("treatment" %in% names(d) &&
        length(unique(as.character(d$treatment[idx])))!=1L)
      stop("Treatment must not change inside one fish recording",
           call.=FALSE)
    block <- integer()
    for (j in seq_along(idx)) {
      if (!valid[idx[j]] ||
          (length(block)>0L && j>1L &&
           t[j]-t[j-1L]>max_gap_s)) {
        if (length(block)>=min_segment) {
          segment_count <- segment_count+1L
          segments[block] <- segment_count
        }
        block <- integer()
      }
      if (valid[idx[j]]) block <- c(block,idx[j])
    }
    if (length(block)>=min_segment) {
      segment_count <- segment_count+1L
      segments[block] <- segment_count
    }
  }
  d$hmm_usable <- valid
  d$hmm_value <- ifelse(valid,d[[outcome]],NA_real_)
  d$hmm_segment <- segments
  d
}

.aqt_hmm_lse <- function(z) {
  m <- max(z)
  if (!is.finite(m)) return(-Inf)
  m+log(sum(exp(z-m)))
}

.aqt_hmm_segment_decode <- function(y,means,sds,transition,initial) {
  n <- length(y)
  k <- length(means)
  emission <- vapply(seq_len(k),function(j)
    stats::dnorm(y,mean=means[j],sd=sds[j],log=TRUE),
    numeric(n))
  if (is.null(dim(emission))) emission <- matrix(emission,ncol=k)
  log_trans <- log(transition)
  alpha <- matrix(-Inf,n,k)
  beta <- matrix(-Inf,n,k)
  delta <- matrix(-Inf,n,k)
  backptr <- matrix(NA_integer_,n,k)
  alpha[1L,] <- log(initial)+emission[1L,]
  delta[1L,] <- alpha[1L,]
  if (n>1L) for (i in seq.int(2L,n)) {
    for (s in seq_len(k)) {
      alpha[i,s] <- emission[i,s]+
        .aqt_hmm_lse(alpha[i-1L,]+log_trans[,s])
      score <- delta[i-1L,]+log_trans[,s]
      backptr[i,s] <- which.max(score)
      delta[i,s] <- emission[i,s]+max(score)
    }
  }
  ll <- .aqt_hmm_lse(alpha[n,])
  if (!is.finite(ll))
    stop("HMM state parameters give nonfinite sequence likelihood",
         call.=FALSE)
  beta[n,] <- 0
  if (n>1L) for (i in seq.int(n-1L,1L,by=-1L)) {
    for (s in seq_len(k))
      beta[i,s] <- .aqt_hmm_lse(
        log_trans[s,]+emission[i+1L,]+beta[i+1L,])
  }
  post <- exp(alpha+beta-ll)
  post <- post/rowSums(post)
  if (any(!is.finite(post)))
    stop("HMM posterior normalization failed",call.=FALSE)
  states <- rep(NA_integer_,n)
  states[n] <- which.max(delta[n,])
  if (n>1L) for (i in seq.int(n-1L,1L,by=-1L))
    states[i] <- backptr[i+1L,states[i+1L]]
  entropy <- -rowSums(ifelse(post>0,post*log(pmax(post,.Machine$double.xmin)),0))
  list(posterior=post,path=states,entropy=entropy,loglik=ll)
}

#' Decode bounded fish behavioural states under an explicit Gaussian HMM
#'
#' Uses caller-specified (NOT learned) Gaussian state means and standard
#' deviations, an initial distribution and a row-stochastic transition
#' matrix. Forward-backward yields observation-conditional posterior state
#' probabilities; Viterbi yields a single descriptive state sequence.
#' Different fish, sessions, cameras and tanks are never joined. Missing
#' observations, invalid observed flags and time gaps above max_gap_s
#' break the Markov chain. Short valid runs remain explicitly unclassified.
#' State names do not establish fish stress, welfare, preference or causal
#' responses. No treatment p-values or uncertainty calibration are supplied.
#'
#' @param data Data frame with session_id,camera_id,track_id,time_s and
#'   a numeric outcome. Optional observed,tank_id,treatment are preserved.
#' @param outcome Name of observed numeric measure (default speed).
#' @param state_means Strictly increasing externally justified state means.
#' @param state_sds Positive Gaussian SD per state.
#' @param transition K-by-K row-stochastic transition probabilities.
#' @param initial Optional initial probability vector; equal by default.
#' @param state_labels Optional distinct nonempty descriptive names.
#' @param max_gap_s Maximum elapsed time to join adjacent samples.
#' @param min_segment Minimum consecutive observed samples to decode.
#' @return aqt_hmm_states with posterior hmm_p1..hmm_pK, Viterbi state,
#'   entropy, explicit missingness, segments and model/likelihood metadata.
#' @export
aqt_hmm_decode <- function(
    data,outcome="speed",state_means,state_sds,transition,
    initial=NULL,state_labels=NULL,max_gap_s=.5,min_segment=3L) {
  if (!is.numeric(state_means) || any(!is.finite(state_means)) ||
      length(state_means)<2L || length(state_means)>5L ||
      any(diff(state_means)<=0))
    stop("Provide 2..5 strictly increasing finite state means",
         call.=FALSE)
  k <- length(state_means)
  if (!is.numeric(state_sds) || length(state_sds)!=k ||
      any(!is.finite(state_sds)) || any(state_sds<=0))
    stop("Provide one strictly positive finite SD per state",
         call.=FALSE)
  if (!is.matrix(transition) || !is.numeric(transition) ||
      !identical(dim(transition),c(as.integer(k),as.integer(k))) ||
      any(!is.finite(transition)) || any(transition<0) ||
      any(abs(rowSums(transition)-1)>1e-8))
    stop("transition must be a nonnegative row-stochastic K-by-K matrix",
         call.=FALSE)
  if (is.null(initial)) initial <- rep(1/k,k)
  if (!is.numeric(initial) || length(initial)!=k ||
      any(!is.finite(initial)) || any(initial<0) ||
      abs(sum(initial)-1)>1e-8)
    stop("initial must be a probability vector summing to one",
         call.=FALSE)
  if (is.null(state_labels)) state_labels <- paste0("state_",seq_len(k))
  if (!is.character(state_labels) || length(state_labels)!=k ||
      anyNA(state_labels) || any(!nzchar(trimws(state_labels))) ||
      anyDuplicated(state_labels))
    stop("state_labels must be distinct complete descriptions",
         call.=FALSE)
  d <- .aqt_hmm_prepare(data,outcome,max_gap_s,min_segment)
  segments <- sort(unique(stats::na.omit(d$hmm_segment)))
  if (!length(segments))
    stop("No contiguous observed fish segments meet min_segment",
         call.=FALSE)
  n <- nrow(d)
  d$hmm_state <- rep(NA_integer_,n)
  d$hmm_state_label <- rep(NA_character_,n)
  d$hmm_entropy <- rep(NA_real_,n)
  pcols <- paste0("hmm_p",seq_len(k))
  for (nm in pcols) d[[nm]] <- rep(NA_real_,n)
  loglik <- numeric(length(segments))
  for (q in seq_along(segments)) {
    idx <- which(d$hmm_segment==segments[q])
    result <- .aqt_hmm_segment_decode(
      d$hmm_value[idx],state_means,state_sds,transition,initial)
    d$hmm_state[idx] <- result$path
    d$hmm_state_label[idx] <- state_labels[result$path]
    d$hmm_entropy[idx] <- result$entropy
    for (j in seq_len(k))
      d[[pcols[j]]][idx] <- result$posterior[,j]
    loglik[q] <- result$loglik
  }
  class(d) <- c("aqt_hmm_states","data.frame")
  attr(d,"aqt_hmm_model") <- list(
    means=state_means,sds=state_sds,transition=transition,
    initial=initial,labels=state_labels,
    parameters_estimated_from_data=FALSE)
  attr(d,"aqt_hmm_outcome") <- outcome
  attr(d,"aqt_hmm_max_gap_s") <- max_gap_s
  attr(d,"aqt_hmm_min_segment") <- min_segment
  attr(d,"aqt_hmm_segment_loglik") <-
    data.frame(segment=segments,loglik=loglik)
  attr(d,"aqt_hmm_total_loglik") <- sum(loglik)
  attr(d,"aqt_hmm_welfare_certified") <- FALSE
  d
}

#' Summarize decoded fish states without pseudoreplication
#'
#' Reports per-scoped-fish observation counts, classified fractions and
#' Viterbi switching counts. Switches never cross tracking gaps, missing
#' rows or independently decoded segments. Fractions count VIDEO SAMPLES,
#' not physical durations or independent experimental replicates.
#' Neither this summary nor its state posterior is a tank-level treatment
#' test, calibrated confidence interval or fish welfare endpoint.
#'
#' @param decoded An aqt_hmm_states object from aqt_hmm_decode.
#' @return One row per fish and state, retaining optional tank/treatment IDs.
#' @export
aqt_hmm_state_summary <- function(decoded) {
  if (!inherits(decoded,"aqt_hmm_states") ||
      !all(c("hmm_state","hmm_segment","hmm_usable") %in% names(decoded)))
    stop("Expected aqt_hmm_states",call.=FALSE)
  ids <- c("session_id","camera_id","track_id",
           intersect("tank_id",names(decoded)))
  key <- do.call(paste,c(decoded[ids],list(sep="\r")))
  labels <- attr(decoded,"aqt_hmm_model")$labels
  out <- list();z <- 0L
  for (idx in split(seq_len(nrow(decoded)),key)) {
    a <- decoded[idx,,drop=FALSE]
    modelled <- which(!is.na(a$hmm_state))
    if (!length(modelled)) next
    switch <- 0L
    if (nrow(a)>1L) for (j in seq.int(2L,nrow(a))) {
      if (!is.na(a$hmm_segment[j]) &&
          !is.na(a$hmm_segment[j-1L]) &&
          a$hmm_segment[j]==a$hmm_segment[j-1L] &&
          a$hmm_state[j]!=a$hmm_state[j-1L])
        switch <- switch+1L
    }
    for (state in seq_along(labels)) {
      z <- z+1L
      row <- data.frame(
        session_id=as.character(a$session_id[1L]),
        camera_id=as.character(a$camera_id[1L]),
        track_id=as.character(a$track_id[1L]),
        state=state,state_label=labels[state],
        n_input=nrow(a),n_observed=sum(a$hmm_usable),
        n_modelled=length(modelled),
        n_unclassified=nrow(a)-length(modelled),
        n_segments=length(unique(a$hmm_segment[modelled])),
        n_state_observations=sum(a$hmm_state[modelled]==state),
        fraction_of_modelled_samples=mean(a$hmm_state[modelled]==state),
        n_switches_total=switch,
        stringsAsFactors=FALSE)
      for (nm in intersect(c("tank_id","treatment"),names(a)))
        row[[nm]] <- as.character(a[[nm]][1L])
      out[[z]] <- row
    }
  }
  if (!length(out)) stop("No decoded fish states to summarize",call.=FALSE)
  result <- do.call(rbind,out)
  rownames(result) <- NULL
  attr(result,"aqt_hmm_independent_tank_test") <- FALSE
  result
}
