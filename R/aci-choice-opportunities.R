# Animal-Computer Interaction: offered opportunities are distinct from
# exercised choices. Analyses do not infer preference, agency or welfare.

#' Validate externally recorded animal choice opportunities and selections
#'
#' A long table contains one row per candidate option, fish and trial.
#' An option may be unavailable (offered=FALSE) but cannot be selected
#' unless offered. Each fish/trial chooses at most one option; a
#' non-selection is explicitly allowed. Option sets with >=2 offered
#' alternatives count as "choice opportunities" for this descriptive
#' module; a single offered option is not evidence of free choice.
#'
#' @param data Long table with session_id,tank_id,fish_id,trial_id,
#'   option_id,trial_s,trial_end_s,offered,selected,choice_s.
#'   choice_s is numeric NA for non-selected options.
#' @return aqt_aci_choice_log with offered option set and choice latency.
#' @export
aqt_aci_choice_log <- function(data) {
  required <- c("session_id","tank_id","fish_id","trial_id",
                "option_id","trial_s","trial_end_s",
                "offered","selected","choice_s")
  if (!is.data.frame(data) || !nrow(data) ||
      !all(required %in% names(data)))
    stop("Expected an ACI long table of offered and selected options",
         call.=FALSE)
  d <- as.data.frame(data)
  for (col in required[1:5]) {
    x <- as.character(d[[col]])
    if (anyNA(x) || any(!nzchar(trimws(x))))
      stop("Fish, tank, trial and option identifiers must be nonmissing",
           call.=FALSE)
    d[[col]] <- x
  }
  if (!all(vapply(d[c("trial_s","trial_end_s","choice_s")],
                  is.numeric,logical(1L))) ||
      any(!is.finite(d$trial_s)) ||
      any(!is.finite(d$trial_end_s)) ||
      any(is.infinite(d$choice_s)) ||
      any(d$trial_end_s<=d$trial_s))
    stop("Trial/choice timestamps are invalid or their window is nonpositive",
         call.=FALSE)
  if (!is.logical(d$offered) || anyNA(d$offered) ||
      !is.logical(d$selected) || anyNA(d$selected))
    stop("Offered and selected indicators must be nonmissing logical",
         call.=FALSE)
  if (any(d$selected & !d$offered))
    stop("An unavailable option cannot be selected",call.=FALSE)
  if (any(d$selected & !is.finite(d$choice_s)) ||
      any(!d$selected & !is.na(d$choice_s)))
    stop("Choice timestamps required for selections only",call.=FALSE)
  if (any(d$selected & (d$choice_s<d$trial_s |
                        d$choice_s>d$trial_end_s),na.rm=TRUE))
    stop("Choice timestamp is outside its opportunity window",
         call.=FALSE)
  key <- paste(d$session_id,d$fish_id,d$trial_id,sep="\r")
  if (anyDuplicated(paste(key,d$option_id,sep="\r")))
    stop("Duplicate option within a fish opportunity",call.=FALSE)
  for (idx in split(seq_len(nrow(d)),key)) {
    x <- d[idx,,drop=FALSE]
    if (length(unique(x$tank_id))!=1L ||
        length(unique(x$trial_s))!=1L ||
        length(unique(x$trial_end_s))!=1L)
      stop("Fish opportunity must have fixed tank and event window",
           call.=FALSE)
    if (!any(x$offered))
      stop("An opportunity requires at least one offered option",
           call.=FALSE)
    if (sum(x$selected)>1L)
      stop("Multiple selected options in the same fish trial",call.=FALSE)
  }
  local <- paste(d$session_id,d$fish_id,sep="\r")
  for (idx in split(seq_len(nrow(d)),local))
    if (length(unique(d$tank_id[idx]))!=1L)
      stop("A fish cannot change its tank within the same session",
           call.=FALSE)
  d$choice_latency_s <- ifelse(d$selected,d$choice_s-d$trial_s,NA_real_)
  class(d) <- c("aqt_aci_choice_log","data.frame")
  attr(d,"opportunity_verified") <- FALSE
  attr(d,"animal_agency_claimed") <- FALSE
  d
}

#' Separate offered fish choices from actually selected alternatives
#'
#' @param choices aqt_aci_choice_log.
#' @return List of per-fish opportunity/selection statistics and
#'   per-option offered/selected conditional counts.
#' @export
aqt_aci_choice_summary <- function(choices) {
  if (!inherits(choices,"aqt_aci_choice_log"))
    stop("Expected an aqt_aci_choice_log",call.=FALSE)
  d <- as.data.frame(choices)
  fish_key <- paste(d$session_id,d$tank_id,d$fish_id,sep="\r")
  trial_key <- paste(fish_key,d$trial_id,sep="\r")
  by_trial <- lapply(split(seq_len(nrow(d)),trial_key),function(idx) {
    x <- d[idx,,drop=FALSE]
    picked <- which(x$selected)
    data.frame(session_id=x$session_id[1L],tank_id=x$tank_id[1L],
      fish_id=x$fish_id[1L],trial_id=x$trial_id[1L],
      n_offered=sum(x$offered),selected=length(picked)>0,
      is_multichoice=sum(x$offered)>=2,
      choice_latency_s=if(length(picked))
        x$choice_latency_s[picked] else NA_real_)
  })
  t <- do.call(rbind,unname(by_trial));rownames(t) <- NULL
  grouped <- split(seq_len(nrow(t)),
    paste(t$session_id,t$tank_id,t$fish_id,sep="\r"))
  per_fish <- lapply(grouped,function(idx) {
    x <- t[idx,,drop=FALSE]
    nchoice <- sum(x$is_multichoice)
    chosen <- sum(x$is_multichoice & x$selected)
    lat <- x$choice_latency_s[is.finite(x$choice_latency_s)]
    data.frame(session_id=x$session_id[1L],tank_id=x$tank_id[1L],
      fish_id=x$fish_id[1L],
      n_opportunities=nrow(x),n_multichoice_opportunities=nchoice,
      n_any_selections=sum(x$selected),n_exercised_multichoice=chosen,
      multichoice_exercise_rate=if(nchoice)chosen/nchoice else NA_real_,
      median_choice_latency_s=if(length(lat))stats::median(lat)
        else NA_real_,
      animal_agency_inferred=FALSE)
  })
  per_fish <- do.call(rbind,unname(per_fish));rownames(per_fish)<-NULL
  option_key <- paste(d$session_id,d$tank_id,d$fish_id,d$option_id,sep="\r")
  per_option <- lapply(split(seq_len(nrow(d)),option_key),function(idx) {
    x <- d[idx,,drop=FALSE]
    n_offered <- sum(x$offered)
    data.frame(session_id=x$session_id[1L],tank_id=x$tank_id[1L],
      fish_id=x$fish_id[1L],option_id=x$option_id[1L],
      n_offered=n_offered,n_selected=sum(x$selected),
      selection_given_offered=if(n_offered)
        sum(x$selected)/n_offered else NA_real_)
  })
  per_option <- do.call(rbind,unname(per_option))
  rownames(per_option) <- NULL
  list(per_fish=per_fish,per_option=per_option,
       per_trial=t,preference_stability_inferred=FALSE,
       welfare_inferred=FALSE)
}

#' Quantify observed inequality in use of offered device choices
#'
#' Computes Gini inequality across per-fish multi-option exercise rates
#' within each session/tank. Each fish MUST have at least one opportunity
#' offering >=2 alternatives; otherwise compare opportunity exposure
#' separately rather than treating unoffered fish as non-users.
#' If no fish selects, inequality is undefined, not falsely zero.
#' Inequality is not evidence of dominance or animal welfare.
#'
#' @param choices aqt_aci_choice_log.
#' @return Per-tank observed exercise-rate Gini and exposure balance.
#' @export
aqt_aci_access_inequality <- function(choices) {
  summary <- aqt_aci_choice_summary(choices)$per_fish
  keys <- paste(summary$session_id,summary$tank_id,sep="\r")
  res <- lapply(split(seq_len(nrow(summary)),keys),function(idx) {
    x <- summary[idx,,drop=FALSE]
    if (nrow(x)<2L || any(x$n_multichoice_opportunities<1L))
      stop("At least two fish with actual multi-option opportunities required",
           call.=FALSE)
    rates <- x$multichoice_exercise_rate
    total <- sum(rates)
    n <- length(rates)
    gini <- if(total>0)
      sum(abs(outer(rates,rates,"-")))/(2*n*total)
      else NA_real_
    data.frame(session_id=x$session_id[1L],
      tank_id=x$tank_id[1L],n_fish=n,
      mean_exercise_rate=mean(rates),
      min_exercise_rate=min(rates),max_exercise_rate=max(rates),
      gini_exercise_rate=gini,
      opportunities_balanced=
        length(unique(x$n_multichoice_opportunities))==1L,
      dominance_or_welfare_inferred=FALSE)
  })
  out <- do.call(rbind,unname(res))
  rownames(out)<-NULL
  out
}
