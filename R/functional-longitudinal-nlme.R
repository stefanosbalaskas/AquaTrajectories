# Longitudinal functional event profiles with fish nested in independent
# tanks. This model is not an identity/optics-error correction or a
# replacement for randomization and experimental design.

#' Validate fully supported event-relative fish curves for mixed models
#'
#' Requires exactly one logged event and one session per independent tank,
#' one fixed between-tank treatment, >=3 independent tanks per arm,
#' >=2 fish per tank, >=6 equally spaced event-relative grid times, and
#' complete (supported, finite) fish curves at ALL times. Nonrandom
#' occlusion and incomplete curves are deliberately NOT imputed.
#' This strict contract supports a common AR(1) within-fish correlation
#' model: the time index is formed from a common equally spaced grid,
#' never from a row number of an incomplete trajectory.
#'
#' @param grid aqt_functional_event_grid with tank_id and treatment.
#' @param treatment_levels Two ordered treatment labels.
#' @return aqt_functional_longitudinal_frame with nested fish scope,
#'   equally spaced AR(1) time index and independent-tank design audit.
#' @export
aqt_functional_longitudinal_prepare <- function(
    grid,treatment_levels=c("control","treatment")) {
  required <- c("session_id","event_id","camera_id","track_id",
                "tank_id","treatment","time_relative_s","value","supported")
  if (!inherits(grid,"aqt_functional_event_grid") ||
      !all(required %in% names(grid)) || !nrow(grid))
    stop("Expected an event-aligned fish grid with tank and treatment",
         call.=FALSE)
  if (!is.character(treatment_levels) ||
      length(treatment_levels)!=2L || anyNA(treatment_levels) ||
      anyDuplicated(treatment_levels) ||
      any(!nzchar(trimws(treatment_levels))))
    stop("Exactly two distinct ordered treatment labels are required",
         call.=FALSE)
  if (!is.numeric(grid$value) || !is.logical(grid$supported) ||
      anyNA(grid$supported) ||
      any(!grid$supported) || any(!is.finite(grid$value)))
    stop("Mixed model requires fully observed finite fish curves; no imputation",
         call.=FALSE)
  for (nm in required[1:6]) {
    v <- as.character(grid[[nm]])
    if (anyNA(v) || any(!nzchar(trimws(v))))
      stop("Fish, tank and event IDs must be complete",call.=FALSE)
  }
  if (!is.numeric(grid$time_relative_s) ||
      any(!is.finite(grid$time_relative_s)))
    stop("Functional model time grid must be finite",call.=FALSE)
  times <- sort(unique(grid$time_relative_s))
  if (length(times)<6L || length(times)>150L)
    stop("Require 6..150 event-relative samples per fish",call.=FALSE)
  steps <- diff(times)
  if (any(steps<=0) ||
      any(abs(steps-steps[1L])>1e-7*max(1,abs(steps[1L]))))
    stop("AR(1) grid must have uniformly spaced recording seconds",
         call.=FALSE)
  audit <- aqt_design_audit(grid)
  if (!setequal(audit$treatment,treatment_levels) ||
      any(audit$n_tanks<3L))
    stop("Require two between-tank groups with >=3 independent tanks per arm",
         call.=FALSE)
  d <- as.data.frame(grid)
  fish_scope <- paste(d$session_id,d$camera_id,d$track_id,sep="\r")
  scoped_tank <- paste(d$tank_id,fish_scope,sep="\r")
  if (anyDuplicated(paste(scoped_tank,d$time_relative_s,sep="\r")))
    stop("Duplicate fish-time observations in event grid",call.=FALSE)
  for (indices in split(seq_len(nrow(d)),scoped_tank)) {
    z <- d[indices,,drop=FALSE]
    if (nrow(z)!=length(times) ||
        !identical(sort(z$time_relative_s),times))
      stop("All fish must have identical complete event-relative grids",
           call.=FALSE)
    if (length(unique(z$tank_id))!=1L ||
        length(unique(z$treatment))!=1L ||
        length(unique(z$event_id))!=1L)
      stop("Fish must have stable tank, treatment and event scope",
           call.=FALSE)
  }
  for (indices in split(seq_len(nrow(d)),d$tank_id)) {
    z <- d[indices,,drop=FALSE]
    if (length(unique(z$session_id))!=1L ||
        length(unique(z$event_id))!=1L)
      stop("Each independently treated tank requires one session and event",
           call.=FALSE)
    fish <- unique(paste(z$camera_id,z$track_id,sep="\r"))
    if (length(fish)<2L)
      stop("At least two observed fish per tank are required",
           call.=FALSE)
  }
  d$treatment <- factor(as.character(d$treatment),levels=treatment_levels)
  d$tank_id <- factor(as.character(d$tank_id))
  d$fish_unit <- factor(fish_scope)
  d$time_index <- match(d$time_relative_s,times)-1L
  d <- d[order(d$tank_id,d$fish_unit,d$time_index),,drop=FALSE]
  rownames(d) <- NULL
  class(d) <- c("aqt_functional_longitudinal_frame","data.frame")
  attr(d,"aqt_design_audit") <- audit
  attr(d,"aqt_time_grid") <- times
  attr(d,"aqt_design_strict") <- TRUE
  d
}

#' Fit a tank/fish nested event-relative spline with optional AR(1) errors
#'
#' Uses independent nlme and splines packages, not unverified
#' EyeTrajectories native R contracts. Fixed effects contain a treatment
#' by natural-cubic-spline-of-time interaction; random intercepts nest
#' fish in independently treated tanks. The optional residual AR(1)
#' within each fish requires the validated common equally spaced grid.
#' Coefficients are associational. With small numbers of randomized tanks,
#' asymptotic Wald tests require special caution. Models omit camera,
#' fish-ID and missing-not-at-random measurement errors.
#'
#' @param prepared aqt_functional_longitudinal_frame.
#' @param spline_df Natural spline degrees of freedom 2..6, below
#'   the number of common observation times.
#' @param residual Correlation structure: ar1 or independent.
#' @param method ML or REML.
#' @return aqt_functional_longitudinal_fit with native nlme lme result,
#'   time grid, nested tank/fish audit and explicit inferential limits.
#' @export
aqt_functional_longitudinal_fit <- function(
    prepared,spline_df=3L,residual=c("ar1","independent"),
    method=c("REML","ML")) {
  if (!inherits(prepared,"aqt_functional_longitudinal_frame") ||
      !isTRUE(attr(prepared,"aqt_design_strict")))
    stop("Use aqt_functional_longitudinal_prepare first",call.=FALSE)
  residual <- match.arg(residual)
  method <- match.arg(method)
  times <- attr(prepared,"aqt_time_grid")
  if (!is.numeric(spline_df) || length(spline_df)!=1L ||
      !is.finite(spline_df) || spline_df!=floor(spline_df) ||
      spline_df<2L || spline_df>6L || spline_df>=length(times)-1L)
    stop("spline_df must be an integer 2..6 below the time design rank",
         call.=FALSE)
  if (!requireNamespace("nlme",quietly=TRUE))
    stop("Install optional nlme for nested longitudinal AR(1)",call.=FALSE)
  if (!requireNamespace("splines",quietly=TRUE))
    stop("Install R recommended splines package",call.=FALSE)
  fixed <- stats::as.formula(paste0(
    "value ~ treatment * splines::ns(time_relative_s, df = ",
    as.integer(spline_df),")"))
  correlation <- if(residual=="ar1")
    nlme::corAR1(value=0.2,
      form=~time_index | tank_id/fish_unit) else NULL
  model <- nlme::lme(
    fixed=fixed,
    random=~1 | tank_id/fish_unit,
    correlation=correlation,
    data=as.data.frame(prepared),
    method=method,na.action=stats::na.fail,
    control=nlme::lmeControl(
      msMaxIter=200,msMaxEval=400,returnObject=FALSE))
  structure(list(model=model,
     fixed_effects=summary(model)$tTable,
     n_tanks=length(unique(prepared$tank_id)),
     n_fish=length(unique(paste(prepared$tank_id,prepared$fish_unit,
                               sep="\r"))),
     design_audit=attr(prepared,"aqt_design_audit"),
     time_grid=times,spline_df=as.integer(spline_df),
     residual_structure=residual,
     model_type="nested Gaussian natural spline longitudinal lme",
     backend="nlme",backend_version=as.character(
       utils::packageVersion("nlme")),
     eye_trajectories_native_r_parity_claim=FALSE,
     causal_identification=FALSE,
     measurement_error_modeled=FALSE,
     independent_tank_units=TRUE,
     coverage_certified=FALSE),
     class="aqt_functional_longitudinal_fit")
}
