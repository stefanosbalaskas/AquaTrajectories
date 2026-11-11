#' Summarize fish behaviour in named windows around recorded events
#'
#' This is a descriptive analysis of already tracked/validated data.
#' Event windows are relative to onset and use intervals [start,end);
#' the final epoch includes its right endpoint. Arbitrarily dense frames
#' are NOT independent experimental replicates. For irregular sample
#' intervals choose time_weighted where possible.
#'
#' @param data Table with session_id, time_s, numeric outcome and unit columns.
#' @param events Event table with session_id,event_id,start_s,end_s.
#' @param outcome Name of numeric feature (e.g. speed).
#' @param windows Named list of finite length-two offset vectors, in seconds.
#' @param unit_cols Columns that identify the observational unit within a
#'   session, such as tank_id, camera_id, track_id; include treatment only
#'   if it is constant within the observational unit.
#' @param estimator sample_mean or trapezoid time_weighted mean.
#' @param min_points Minimum finite observed points for an estimate.
#' @return Descriptive per-session/event/epoch/unit means, counts and time spans.
#' @export
aqt_event_epoch_summary <- function(
    data,events,outcome,
    windows=list(baseline=c(-120,0),response=c(0,120),
                 recovery=c(120,600)),
    unit_cols=c("camera_id","track_id"),
    estimator=c("sample_mean","time_weighted"),
    min_points=2L) {
  estimator <- match.arg(estimator)
  if (!is.data.frame(data) ||
      !all(c("session_id","time_s",outcome,unit_cols) %in% names(data)))
    stop("Missing session, time, outcome or unit columns",call.=FALSE)
  if (!is.character(outcome) || length(outcome)!=1L ||
      !is.numeric(data[[outcome]]))
    stop("outcome must select a numeric column",call.=FALSE)
  if (!is.numeric(data$time_s) ||
      any(!is.finite(data$time_s)))
    stop("time_s must be finite numeric",call.=FALSE)
  if (!is.character(unit_cols) || !length(unit_cols) ||
      anyDuplicated(unit_cols) ||
      any(unit_cols %in% c("session_id","time_s",outcome)))
    stop("Invalid unit_cols",call.=FALSE)
  if (anyNA(data$session_id) ||
      any(!nzchar(as.character(data$session_id))))
    stop("Missing session identifiers",call.=FALSE)
  for (col in unit_cols)
    if (anyNA(data[[col]]) ||
        any(!nzchar(as.character(data[[col]]))))
      stop("Unit identifiers must not be missing",call.=FALSE)
  if (!is.list(windows) || !length(windows) ||
      is.null(names(windows)) || any(!nzchar(names(windows))) ||
      anyDuplicated(names(windows)))
    stop("windows must be a named list of ordered intervals",call.=FALSE)
  for (w in windows)
    if (!is.numeric(w) || length(w)!=2L ||
        any(!is.finite(w)) || w[1L]>=w[2L])
      stop("Every event window requires finite increasing limits",call.=FALSE)
  limits <- do.call(rbind,windows)
  ord <- order(limits[,1L])
  if (length(ord)>1L &&
      any(limits[ord[-1L],1L] < limits[ord[-length(ord)],2L]))
    stop("Epoch windows must not overlap",call.=FALSE)
  if (length(min_points)!=1L || !is.numeric(min_points) ||
      !is.finite(min_points) || min_points<1 ||
      min_points!=floor(min_points))
    stop("min_points must be a positive integer",call.=FALSE)
  e <- aqt_event_table(events)
  results <- list()
  n <- 0L
  for (k in seq_len(nrow(e))) {
    d <- data[as.character(data$session_id)==e$session_id[k],,drop=FALSE]
    if (!nrow(d)) next
    relative <- d$time_s-e$start_s[k]
    for (j in seq_along(windows)) {
      w <- windows[[j]]
      active <- if (j==length(windows))
        relative>=w[1L] & relative<=w[2L]
        else relative>=w[1L] & relative<w[2L]
      subset <- d[active,,drop=FALSE]
      if (!nrow(subset)) next
      keys <- do.call(paste,c(lapply(subset[unit_cols],as.character),
                              list(sep="\r")))
      for (idx in split(seq_len(nrow(subset)),keys)) {
        z <- subset[idx,,drop=FALSE]
        valid <- is.finite(z[[outcome]])
        good <- z[valid,,drop=FALSE]
        if (nrow(good)>1L)
          good <- good[order(good$time_s),,drop=FALSE]
        span <- if (nrow(good)>=2L)
          max(good$time_s)-min(good$time_s) else 0
        if (estimator=="time_weighted" && nrow(good)>=2L &&
            any(diff(good$time_s)<=0))
          stop("time_weighted estimator requires unique timestamps within unit",call.=FALSE)
        v <- NA_real_
        if (nrow(good)>=min_points) {
          if (estimator=="sample_mean") {
            v <- mean(good[[outcome]])
          } else if (nrow(good)>=2L && span>0) {
            dt <- diff(good$time_s)
            v <- sum(dt*(good[[outcome]][-1L]+
                         good[[outcome]][-nrow(good)])/2)/span
          }
        }
        n <- n+1L
        row <- data.frame(session_id=e$session_id[k],
          event_id=e$event_id[k],epoch=names(windows)[j],
          window_start_s=w[1L],window_end_s=w[2L],
          n_samples=nrow(z),n_valid=nrow(good),
          observed_span_s=span,value=v,
          estimator=estimator,stringsAsFactors=FALSE)
        for (col in unit_cols) row[[col]] <- z[[col]][1L]
        results[[n]] <- row
      }
    }
  }
  if (!length(results)) return(data.frame())
  out <- do.call(rbind,results)
  rownames(out) <- NULL
  out
}

#' Audit between-tank treatment replication and experimental-unit independence
#'
#' This assumes each tank has one treatment throughout the analyzed period.
#' Crossover or split-plot designs need a different inferential model.
#' n_rows and n_fish never replace the number of independently treated tanks.
#'
#' @param data Table with treatment and tank identifiers.
#' @param treatment_col Treatment assignment column.
#' @param tank_col Independent experimental tank/cluster column.
#' @return Per-treatment independent-tank and row counts with replication flag.
#' @export
aqt_design_audit <- function(data,treatment_col="treatment",tank_col="tank_id") {
  if (!is.data.frame(data) ||
      !all(c(treatment_col,tank_col) %in% names(data)))
    stop("Missing treatment/tank columns",call.=FALSE)
  if (!nrow(data)) stop("No experimental observations",call.=FALSE)
  x <- as.character(data[[treatment_col]])
  tank <- as.character(data[[tank_col]])
  if (anyNA(x) || anyNA(tank) || any(!nzchar(x)) || any(!nzchar(tank)))
    stop("Treatment and tank IDs must be nonmissing",call.=FALSE)
  conflict <- vapply(split(x,tank),
    function(z) length(unique(z))>1L,logical(1L))
  if (any(conflict))
    stop("Treatment varies within tank; between-tank design invalid",call.=FALSE)
  lev <- sort(unique(x))
  out <- do.call(rbind,lapply(lev,function(tr) {
    idx <- which(x==tr)
    data.frame(treatment=tr,n_tanks=length(unique(tank[idx])),
               n_rows=length(idx),replicated=length(unique(tank[idx]))>=2L)
  }))
  rownames(out) <- NULL
  out
}

#' Estimate a tank-replicated difference in event-related changes
#'
#' For each tank, mean values from the specified before/after epochs are
#' contrasted. The between-group estimand is mean(change in treatment) -
#' mean(change in control), giving every independent tank equal weight.
#' Bootstrap resampling is performed *over tanks within treatment*, never
#' over individual video frames or fish. This is a descriptive difference-
#' in-differences-like association, not causal identification by itself.
#'
#' @param epochs Summaries containing tank_id, treatment, epoch, value.
#' @param treatment_levels Exactly c(control_label,treatment_label).
#' @param baseline,response Names of before and after event epochs.
#' @param tank_col,treatment_col,epoch_col,value_col Column names.
#' @param draws Number of tank-level bootstrap replications, >=100.
#' @param level Central percentile interval mass.
#' @param seed Integer seed; RNG state is preserved.
#' @return List of contrast, percentile interval and per-tank changes.
#' @export
aqt_tank_event_contrast <- function(
    epochs,treatment_levels=c("control","treatment"),
    baseline="baseline",response="response",
    tank_col="tank_id",treatment_col="treatment",
    epoch_col="epoch",value_col="value",
    draws=999L,level=.95,seed=7L) {
  cols <- c(tank_col,treatment_col,epoch_col,value_col)
  if (!is.data.frame(epochs) || !all(cols %in% names(epochs)))
    stop("Missing tank, treatment, epoch or value columns",call.=FALSE)
  if (!is.numeric(epochs[[value_col]]))
    stop("value column must be numeric",call.=FALSE)
  if (!is.character(treatment_levels) ||
      length(treatment_levels)!=2L || anyDuplicated(treatment_levels) ||
      any(!nzchar(treatment_levels)))
    stop("Specify exactly two distinct ordered treatment levels",call.=FALSE)
  if (length(baseline)!=1L || length(response)!=1L ||
      baseline==response)
    stop("Distinct baseline and response epochs are required",call.=FALSE)
  if (length(draws)!=1L || !is.numeric(draws) || !is.finite(draws) ||
      draws<100 || draws!=floor(draws))
    stop("draws must be an integer >=100",call.=FALSE)
  if (length(level)!=1L || !is.numeric(level) || !is.finite(level) ||
      level<=0 || level>=1)
    stop("level must be between 0 and 1",call.=FALSE)
  if (length(seed)!=1L || !is.numeric(seed) ||
      !is.finite(seed) || seed!=floor(seed) ||
      seed<0 || seed>2147483647)
    stop("Invalid seed",call.=FALSE)
  audit <- aqt_design_audit(epochs,treatment_col,tank_col)
  if (!setequal(audit$treatment,treatment_levels))
    stop("Data must contain precisely the two declared treatment levels",call.=FALSE)
  if (any(audit$n_tanks<2L))
    stop("At least two independent tanks in each group are required",call.=FALSE)
  tank <- as.character(epochs[[tank_col]])
  trt <- as.character(epochs[[treatment_col]])
  ep <- as.character(epochs[[epoch_col]])
  val <- epochs[[value_col]]
  pieces <- lapply(split(seq_len(nrow(epochs)),tank),function(idx) {
    d <- data.frame(tank_id=tank[idx],treatment=trt[idx],
                    epoch=ep[idx],value=val[idx])
    pre <- d$value[d$epoch==baseline]
    post <- d$value[d$epoch==response]
    pre <- pre[is.finite(pre)]; post <- post[is.finite(post)]
    if (!length(pre) || !length(post))
      stop("Each tank requires finite baseline and response observations",call.=FALSE)
    data.frame(tank_id=d$tank_id[1L],treatment=d$treatment[1L],
       n_baseline=length(pre),n_response=length(post),
       mean_baseline=mean(pre),mean_response=mean(post),
       change=mean(post)-mean(pre))
  })
  per_tank <- do.call(rbind,unname(pieces))
  control <- per_tank$change[per_tank$treatment==treatment_levels[1L]]
  treated <- per_tank$change[per_tank$treatment==treatment_levels[2L]]
  estimate <- mean(treated)-mean(control)
  had <- exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE)
  if (had) original <- get(".Random.seed",envir=.GlobalEnv)
  on.exit({
    if (had) assign(".Random.seed",original,envir=.GlobalEnv)
    else if (exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
      rm(".Random.seed",envir=.GlobalEnv)
  },add=TRUE)
  set.seed(as.integer(seed))
  bootstrap <- replicate(draws,
    mean(sample(treated,length(treated),replace=TRUE)) -
      mean(sample(control,length(control),replace=TRUE)))
  bounds <- unname(stats::quantile(bootstrap,
    probs=c((1-level)/2,1-(1-level)/2),names=FALSE))
  list(estimate=estimate,lower=bounds[1L],upper=bounds[2L],
       bootstrap_sd=stats::sd(bootstrap),draws=draws,level=level,
       treatment_levels=treatment_levels,
       n_tanks_control=length(control),n_tanks_treatment=length(treated),
       per_tank=per_tank,
       interpretation="tank-level difference in mean within-tank event changes",
       causal_identification=FALSE)
}
