# Event-aligned functional analysis with explicit missingness and
# independent-tank replication. These are finite-grid descriptive methods,
# NOT sparse FPCA, automatic welfare assessment or causal inference.

#' Align observed fish behaviour to event-relative functional time
#'
#' Interpolates only between adjacent *observed* source samples separated
#' by at most max_gap_s. Missing source frames, insufficient coverage and
#' large gaps are never silently bridged. The time grid is in REAL seconds
#' relative to externally logged event onset, not warped to 0..1.
#' Grouped fish remain distinct; tank_id/treatment can be retained as
#' observational metadata, not treated as independent fish replicates.
#'
#' @param data Long frame with session_id, camera_id, track_id, time_s,
#'   numeric outcome and optional logical observed, tank_id, treatment.
#' @param events Canonical events, at most one per session.
#' @param outcome Numeric observed variable such as speed, x, y or z.
#' @param grid_s Strictly increasing finite event-relative seconds.
#' @param max_gap_s Largest permissible adjacent observation gap.
#' @return aqt_functional_event_grid with supported and missing grid points.
#' @export
aqt_functional_event_grid <- function(data,events,outcome="speed",
                                      grid_s=seq(-5,5,length.out=21L),
                                      max_gap_s=.5) {
  required <- c("session_id","camera_id","track_id","time_s",outcome)
  if (!is.data.frame(data) || !nrow(data) ||
      !all(required %in% names(data)) ||
      !is.character(outcome) || length(outcome)!=1L ||
      !is.numeric(data[[outcome]]))
    stop("Expected nonempty scoped fish observations and numeric outcome",call.=FALSE)
  if (!is.numeric(data$time_s) || any(!is.finite(data$time_s)) ||
      any(is.infinite(data[[outcome]])))
    stop("Timestamps must be finite; outcomes cannot be infinite",call.=FALSE)
  if (!is.numeric(grid_s) || length(grid_s)<2L || length(grid_s)>500L ||
      any(!is.finite(grid_s)) || any(diff(grid_s)<=0))
    stop("grid_s must have 2..500 strictly increasing finite time points",
         call.=FALSE)
  if (!is.numeric(max_gap_s) || length(max_gap_s)!=1L ||
      !is.finite(max_gap_s) || max_gap_s<=0)
    stop("max_gap_s must be a positive finite recording gap limit",
         call.=FALSE)
  if ("observed" %in% names(data) &&
      (!is.logical(data$observed) || anyNA(data$observed)))
    stop("observed must be a nonmissing logical flag",call.=FALSE)
  ids <- c("session_id","camera_id","track_id")
  for (col in c(ids,intersect(c("tank_id","treatment"),names(data)))) {
    v <- as.character(data[[col]])
    if (anyNA(v) || any(!nzchar(trimws(v))))
      stop("Identity, treatment and tank scope cannot be missing",call.=FALSE)
  }
  ev <- aqt_event_table(events)
  if (anyDuplicated(ev$session_id))
    stop("One event per session is required; separate repeated-event studies",
         call.=FALSE)
  groups <- split(seq_len(nrow(data)),
                  interaction(data$session_id,data$camera_id,
                              data$track_id,drop=TRUE))
  result <- vector("list",length(groups))
  k <- 0L
  for (index in groups) {
    d <- data[index,,drop=FALSE]
    event <- ev[ev$session_id==as.character(d$session_id[1L]),,drop=FALSE]
    if (!nrow(event)) next
    for (field in intersect(c("tank_id","treatment"),names(d)))
      if (length(unique(as.character(d[[field]])))!=1L)
        stop("Tank and treatment cannot change within a fish recording",
             call.=FALSE)
    d <- d[order(d$time_s),,drop=FALSE]
    t <- d$time_s
    if (any(diff(t)<=0))
      stop("Repeated timestamps within scoped fish recording",call.=FALSE)
    valid <- if ("observed" %in% names(d))
      d$observed & is.finite(d[[outcome]]) else is.finite(d[[outcome]])
    obs <- rep(NA_real_,length(grid_s))
    for (j in seq_along(grid_s)) {
      target <- event$start_s[1L]+grid_s[j]
      exact <- which(t==target)
      if (length(exact)==1L && valid[exact]) {
        obs[j] <- d[[outcome]][exact]
        next
      }
      left <- findInterval(target,t)
      if (left>=1L && left<length(t) &&
          t[left]<target && target<t[left+1L] &&
          valid[left] && valid[left+1L] &&
          (t[left+1L]-t[left])<=max_gap_s) {
        ratio <- (target-t[left])/(t[left+1L]-t[left])
        obs[j] <- (1-ratio)*d[[outcome]][left]+
          ratio*d[[outcome]][left+1L]
      }
    }
    k <- k+1L
    record <- data.frame(
      session_id=as.character(d$session_id[1L]),
      camera_id=as.character(d$camera_id[1L]),
      track_id=as.character(d$track_id[1L]),
      event_id=as.character(event$event_id[1L]),
      time_relative_s=as.numeric(grid_s),
      value=obs,supported=is.finite(obs),
      outcome=outcome,stringsAsFactors=FALSE)
    for (field in intersect(c("tank_id","treatment"),names(d)))
      record[[field]] <- as.character(d[[field]][1L])
    result[[k]] <- record
  }
  if (!k) stop("No fish sessions match the supplied event log",call.=FALSE)
  result <- do.call(rbind,result[seq_len(k)])
  rownames(result) <- NULL
  class(result) <- c("aqt_functional_event_grid","data.frame")
  attr(result,"aqt_grid_s") <- as.numeric(grid_s)
  attr(result,"aqt_max_gap_s") <- max_gap_s
  attr(result,"aqt_interpolation") <- "only adjacent observed points within max_gap_s"
  result
}

#' Audit the observed support of time-aligned fish functions
#'
#' @param grid Output of aqt_functional_event_grid.
#' @return Per-relative-second visible fish fraction and number of sessions.
#' @export
aqt_functional_coverage <- function(grid) {
  if (!inherits(grid,"aqt_functional_event_grid"))
    stop("Expected an aqt_functional_event_grid",call.=FALSE)
  times <- sort(unique(grid$time_relative_s))
  out <- lapply(times,function(t) {
    d <- grid[grid$time_relative_s==t,,drop=FALSE]
    data.frame(time_relative_s=t,n_fish=nrow(d),
      n_supported=sum(d$supported),fraction_supported=mean(d$supported),
      n_sessions=length(unique(d$session_id)))
  })
  do.call(rbind,out)
}

#' Fit a tank-replicated functional treatment contrast with cluster bands
#'
#' A per-tank mean fish curve is computed FIRST, so each independent tank
#' contributes one curve regardless of fish number or video frame rate.
#' Tanks are then resampled WITHIN treatment arms. The simultaneous
#' max-deviation band is an empirical tank-resampling sensitivity band;
#' coverage is NOT certified by this method, and it does not include
#' camera/identity measurement uncertainty or establish causality.
#' All tanks must cover every requested time; use min_fish_fraction=1
#' (default) to forbid changing observed fish composition at grid points.
#'
#' @param grid Output of aqt_functional_event_grid containing tank and treatment.
#' @param treatment_levels Exactly control,treatment labels.
#' @param min_fish_fraction Required supported fish fraction at each tank/time.
#' @param draws Number of within-arm independent-tank resamples, >=100.
#' @param level Central percentile mass.
#' @param seed Integer R seed, caller global RNG state preserved.
#' @return Per-tank means, time-varying contrasts, pointwise/simultaneous
#'   uncalibrated resampling bands, design audit and caveats.
#' @export
aqt_functional_tank_contrast <- function(
    grid,treatment_levels=c("control","treatment"),
    min_fish_fraction=1,draws=499L,level=.95,seed=1L) {
  if (!inherits(grid,"aqt_functional_event_grid") ||
      !all(c("tank_id","treatment","value","supported",
             "event_id","session_id") %in% names(grid)))
    stop("Functional tank analysis requires an event grid with tank and treatment",
         call.=FALSE)
  if (!is.character(treatment_levels) || length(treatment_levels)!=2L ||
      anyNA(treatment_levels) || anyDuplicated(treatment_levels) ||
      any(!nzchar(treatment_levels)))
    stop("Require two distinct treatment_levels",call.=FALSE)
  if (!is.numeric(min_fish_fraction) || length(min_fish_fraction)!=1L ||
      !is.finite(min_fish_fraction) ||
      min_fish_fraction<=0 || min_fish_fraction>1)
    stop("min_fish_fraction must be in (0,1]",call.=FALSE)
  if (!is.numeric(draws) || length(draws)!=1L ||
      !is.finite(draws) || draws<100L || draws!=floor(draws) ||
      draws>5000L)
    stop("draws must be 100..5000",call.=FALSE)
  if (!is.numeric(level) || length(level)!=1L ||
      !is.finite(level) || level<=0 || level>=1)
    stop("level must be strictly between zero and one",call.=FALSE)
  if (!is.numeric(seed) || length(seed)!=1L || !is.finite(seed) ||
      seed<0 || seed>2147483647 || seed!=floor(seed))
    stop("seed must be a nonnegative 32-bit integer",call.=FALSE)
  audit <- aqt_design_audit(grid)
  if (!setequal(audit$treatment,treatment_levels) ||
      any(audit$n_tanks<2L))
    stop("Exactly two treatments, each with >=2 independent tanks, required",
         call.=FALSE)
  by_tank <- split(seq_len(nrow(grid)),as.character(grid$tank_id))
  times <- sort(unique(grid$time_relative_s))
  tank_records <- vector("list",length(by_tank))
  for (i in seq_along(by_tank)) {
    d <- grid[by_tank[[i]],,drop=FALSE]
    if (length(unique(d$session_id))!=1L ||
        length(unique(d$event_id))!=1L)
      stop("One independent event/session per tank is required",call.=FALSE)
    fish_key <- paste(d$camera_id,d$track_id,sep="\r")
    nfish <- length(unique(fish_key))
    if (anyDuplicated(paste(fish_key,d$time_relative_s,sep="\r")))
      stop("Duplicate fish/grid times in tank",call.=FALSE)
    if (!setequal(unique(d$time_relative_s),times))
      stop("Inconsistent functional time support across tanks",call.=FALSE)
    v <- vapply(times,function(t) {
      slice <- d[d$time_relative_s==t,,drop=FALSE]
      n <- sum(slice$supported & is.finite(slice$value))
      if (n/nfish+1e-12<min_fish_fraction || n<1L)
        stop("Insufficient independent-tank fish coverage at functional time ",
             t,call.=FALSE)
      mean(slice$value[slice$supported & is.finite(slice$value)])
    },numeric(1L))
    tank_records[[i]] <- data.frame(tank_id=as.character(d$tank_id[1L]),
       treatment=as.character(d$treatment[1L]),
       time_relative_s=times,value=v,n_fish=nfish)
  }
  tank_mean <- do.call(rbind,tank_records)
  groups <- lapply(treatment_levels,function(tr) {
    d <- tank_mean[tank_mean$treatment==tr,,drop=FALSE]
    ids <- unique(d$tank_id)
    v <- vapply(ids,function(id) {
      z <- d[d$tank_id==id,,drop=FALSE]
      z$value[match(times,z$time_relative_s)]
    },numeric(length(times)))
    if (!is.matrix(v)) v <- matrix(v,ncol=length(ids))
    v
  })
  estimate <- rowMeans(groups[[2L]])-rowMeans(groups[[1L]])
  had <- exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE)
  if (had) previous <- get(".Random.seed",envir=.GlobalEnv)
  on.exit({
    if (had) assign(".Random.seed",previous,envir=.GlobalEnv)
    else if (exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
      rm(".Random.seed",envir=.GlobalEnv)
  },add=TRUE)
  set.seed(as.integer(seed))
  boot <- matrix(NA_real_,nrow=length(times),ncol=as.integer(draws))
  for (j in seq_len(draws)) {
    a <- groups[[1L]]
    b <- groups[[2L]]
    ja <- sample.int(ncol(a),ncol(a),replace=TRUE)
    jb <- sample.int(ncol(b),ncol(b),replace=TRUE)
    boot[,j] <- rowMeans(b[,jb,drop=FALSE])-
      rowMeans(a[,ja,drop=FALSE])
  }
  lo <- (1-level)/2
  point_l <- apply(boot,1L,stats::quantile,probs=lo,names=FALSE)
  point_u <- apply(boot,1L,stats::quantile,probs=1-lo,names=FALSE)
  max_dev <- apply(abs(boot-estimate),2L,max)
  critical <- unname(stats::quantile(max_dev,probs=level))
  summary <- data.frame(time_relative_s=times,contrast=estimate,
    pointwise_lower=as.numeric(point_l),
    pointwise_upper=as.numeric(point_u),
    simultaneous_lower=estimate-critical,
    simultaneous_upper=estimate+critical)
  list(curve=summary,per_tank=tank_mean,design_audit=audit,
       treatment_levels=treatment_levels,
       resamples=as.integer(draws),level=level,
       critical_max_deviation=critical,
       calibrated_coverage=FALSE,causal_identification=FALSE,
       measurement_error_modeled=FALSE,
       interpretation="descriptive tank-replicated functional contrasts; independent-tank resampling band not coverage-certified")
}
