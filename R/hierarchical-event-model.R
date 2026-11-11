#' Prepare fish-within-tank event measurements for hierarchical analysis
#'
#' Requires at least two independent experimental tanks per treatment arm
#' and exactly two observed epochs for every scoped fish. A tank must not
#' change assigned treatment. An event is included once per fish: studies
#' with many events, crossovers, autoregressive designs or interference
#' need a different statistical model.
#'
#' @param epochs Data frame with tank_id, treatment, camera_id, track_id,
#'   epoch, value; event_id is optionally allowed but must be unique.
#' @param treatment_levels Exactly c(control,treatment).
#' @param epoch_levels Exactly c(baseline,response).
#' @return Validated aqt_hierarchical_event_frame with factors for
#'   treatment, epoch, tank_id and fish-within-tank.
#' @export
aqt_hierarchical_event_prepare <- function(
    epochs,treatment_levels=c("control","treatment"),
    epoch_levels=c("baseline","response")) {
  needed <- c("tank_id","treatment","camera_id","track_id","epoch","value")
  if (!is.data.frame(epochs) || !all(needed %in% names(epochs)) ||
      !nrow(epochs))
    stop("Expected nonempty tank, treatment, fish, epoch and value data",
         call.=FALSE)
  if (!is.numeric(epochs$value) || any(!is.finite(epochs$value)))
    stop("Event values must be finite numeric; inspect missingness first",
         call.=FALSE)
  for (col in needed[1:5]) {
    if (anyNA(epochs[[col]]) ||
        any(!nzchar(as.character(epochs[[col]]))))
      stop("Hierarchical grouping IDs and epochs must be complete",
           call.=FALSE)
  }
  if (!is.character(treatment_levels) ||
      length(treatment_levels)!=2L || anyDuplicated(treatment_levels) ||
      !is.character(epoch_levels) || length(epoch_levels)!=2L ||
      anyDuplicated(epoch_levels))
    stop("Two distinct ordered treatment and epoch levels are required",
         call.=FALSE)
  audit <- aqt_design_audit(epochs,"treatment","tank_id")
  if (!setequal(audit$treatment,treatment_levels) ||
      any(audit$n_tanks<2L))
    stop("Require two treatment groups and >=2 independent tanks per group",
         call.=FALSE)
  if (!setequal(as.character(unique(epochs$epoch)),epoch_levels))
    stop("Only the two specified event epochs are supported",call.=FALSE)
  if ("event_id" %in% names(epochs) &&
      length(unique(as.character(epochs$event_id)))>1L)
    stop("Repeated events require a different hierarchical study design",
         call.=FALSE)
  d <- as.data.frame(epochs)
  d$tank_id <- factor(as.character(d$tank_id))
  d$treatment <- factor(as.character(d$treatment),
                        levels=treatment_levels)
  d$epoch <- factor(as.character(d$epoch),levels=epoch_levels)
  d$fish_unit <- interaction(as.character(d$camera_id),
                             as.character(d$track_id),
                             drop=TRUE,sep="_")
  fish_key <- paste(d$tank_id,d$fish_unit,sep="\r")
  duplicates <- paste(fish_key,d$epoch,sep="\r")
  if (anyDuplicated(duplicates))
    stop("Duplicate fish-within-tank epoch; aggregate sessions first",
         call.=FALSE)
  for (idx in split(seq_len(nrow(d)),fish_key)) {
    if (!setequal(as.character(d$epoch[idx]),epoch_levels))
      stop("Each fish requires both observed event epochs",call.=FALSE)
  }
  class(d) <- c("aqt_hierarchical_event_frame","data.frame")
  attr(d,"aqt_design_audit") <- audit
  d
}

#' Fit a tank/fish nested longitudinal model using established nlme
#'
#' Fits a simple Gaussian linear mixed-effects model with treatment,
#' epoch and their interaction as fixed effects plus nested random
#' intercepts for independent tanks and fish within tank. This is not
#' automatic causal identification, nor does it model heteroscedasticity,
#' autocorrelation, calibration errors or identity uncertainty. Report
#' singularity/convergence, treatment replication and residual diagnostics.
#'
#' @param prepared Data from aqt_hierarchical_event_prepare().
#' @param method "REML" (default) or "ML".
#' @return List containing native nlme fit and a design audit.
#' @export
aqt_hierarchical_event_fit <- function(prepared,method=c("REML","ML")) {
  if (!inherits(prepared,"aqt_hierarchical_event_frame"))
    stop("Use aqt_hierarchical_event_prepare() first",call.=FALSE)
  method <- match.arg(method)
  if (!requireNamespace("nlme",quietly=TRUE))
    stop("Install optional package nlme to fit mixed-effects models",
         call.=FALSE)
  model <- nlme::lme(
    fixed=value ~ treatment*epoch,
    random=~1 | tank_id/fish_unit,
    data=as.data.frame(prepared),method=method,
    na.action=stats::na.fail,
    control=nlme::lmeControl(returnObject=FALSE))
  list(model=model,
    design_audit=attr(prepared,"aqt_design_audit"),
    n_tanks=length(unique(prepared$tank_id)),
    n_fish=length(unique(paste(prepared$tank_id,
                                prepared$fish_unit,sep="\r"))),
    backend="nlme",model_scope="Gaussian nested random-intercept event model",
    treatment_causal=FALSE,
    measurement_error_modeled=FALSE,
    identity_error_modeled=FALSE)
}
