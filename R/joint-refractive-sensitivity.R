# Joint conditional sensitivity scenarios: two-view pixel localization noise,
# coherent camera extrinsics/window optics and discrete fish identity swaps.
# This is NOT a calibrated posterior or frequentist joint confidence model.

.aqt_joint_sd <- function(x,name) {
  if (!is.numeric(x) || !length(x) ||
      !(length(x) %in% c(1L,2L)) ||
      any(!is.finite(x)) || any(x<0))
    stop(name," must be nonnegative with length one or two",call.=FALSE)
  rep(x,length.out=2L)
}

#' Simulate coherent glass-camera and discrete fish-ID uncertainty scenarios
#'
#' For each scenario: draw one physical calibration perturbation for EACH
#' camera (shared across all video frames), one shared glass/water-index
#' offset across the two views, camera-pixel localization errors, then
#' reconstruct 3D reviewed correspondences through both glass interfaces.
#' Optionally sample whole-suffix fish identity swaps, not independent
#' identity labels at each frame. All SD inputs are externally assumed
#' sensitivity parameters, NOT calibrated noise distributions.
#'
#' An optical draw that creates invalid glass or ray geometry FAILS
#' explicitly; it is never silently omitted from ensemble summaries.
#'
#' @param view_a,view_b 2D image aqt_tracks for distinct cameras.
#' @param correspondences Externally reviewed cross-camera fish matches,
#'   optionally with tank_id and treatment fields.
#' @param camera_a,camera_b Two aqt_flatport_camera optical models.
#' @param identity_events Optional prospective swaps of reconstructed fish
#'   labels, using session_id,camera_id="REFRACTIVE3D", track_a,track_b,
#'   at_s,probability_swap. Only user-specified hypotheses are considered.
#' @param pixel_sd One/two standard deviations in image pixels.
#' @param center_sd One/two physical SDs of camera centre positions.
#' @param glass_thickness_sd One/two physical glass thickness SDs.
#' @param n_glass_sd,n_water_sd Shared dimensionless optical-index SDs.
#' @param draws Number of coherent uncertainty scenarios (>= 10).
#' @param seed Reproducible integer seed; caller RNG remains unchanged.
#' @param max_skew_s,max_ray_separation Clock and physical ray QC limits.
#' @return aqt_joint_refractive_scenarios with per-draw 3D tracks,
#'   physical calibration draws, diagnostics and assumptions.
#' @export
aqt_joint_refractive_scenarios <- function(
    view_a,view_b,correspondences,camera_a,camera_b,
    identity_events=NULL,pixel_sd=0,center_sd=0,
    glass_thickness_sd=0,n_glass_sd=0,n_water_sd=0,
    draws=50L,seed=123L,max_skew_s=.02,max_ray_separation=Inf) {
  aqt_tracks_validate(view_a);aqt_tracks_validate(view_b)
  if (!inherits(camera_a,"aqt_flatport_camera") ||
      !inherits(camera_b,"aqt_flatport_camera"))
    stop("Joint optical scenarios require two flatport cameras",call.=FALSE)
  if (!is.numeric(draws) || length(draws)!=1L ||
      !is.finite(draws) || draws<10L || draws!=floor(draws) ||
      !is.data.frame(correspondences) ||
      as.double(draws)*nrow(correspondences)>250000)
    stop("Invalid draws or ensemble exceeds 250,000 fish positions",
         call.=FALSE)
  if (!is.numeric(seed) || length(seed)!=1L || !is.finite(seed) ||
      seed<0 || seed>2147483000 || seed!=floor(seed))
    stop("seed must be a valid integer between 0 and 2147483000",
         call.=FALSE)
  pixel_sd <- .aqt_joint_sd(pixel_sd,"pixel_sd")
  center_sd <- .aqt_joint_sd(center_sd,"center_sd")
  glass_thickness_sd <- .aqt_joint_sd(
    glass_thickness_sd,"glass_thickness_sd")
  for (x in list(n_glass_sd,n_water_sd))
    if (!is.numeric(x) || length(x)!=1L ||
        !is.finite(x) || x<0)
      stop("Refractive index SDs must be nonnegative finite scalars",
           call.=FALSE)
  if (!is.null(identity_events) && !is.data.frame(identity_events))
    stop("identity_events must be a reviewed candidate-event table",
         call.=FALSE)
  had <- exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE)
  if (had) previous <- get(".Random.seed",envir=.GlobalEnv)
  on.exit({
    if (had) assign(".Random.seed",previous,envir=.GlobalEnv)
    else if (exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
      rm(".Random.seed",envir=.GlobalEnv)
  },add=TRUE)
  set.seed(as.integer(seed))
  paths <- vector("list",as.integer(draws))
  calibration <- vector("list",as.integer(draws))
  quality <- vector("list",as.integer(draws))
  base_cameras <- list(camera_a,camera_b)
  source_views <- list(view_a,view_b)
  for (i in seq_len(draws)) {
    shared_glass <- stats::rnorm(1L,sd=n_glass_sd)
    shared_water <- stats::rnorm(1L,sd=n_water_sd)
    perturbed_cams <- vector("list",2L)
    perturbed_views <- vector("list",2L)
    for (j in 1:2) {
      original <- base_cameras[[j]]
      centre <- original$center+stats::rnorm(3L,sd=center_sd[j])
      thickness <- original$glass_thickness+
        stats::rnorm(1L,sd=glass_thickness_sd[j])
      ng <- original$n_after+shared_glass
      nw <- original$n_water+shared_water
      if (thickness<=0 || ng<=0 || nw<=0)
        stop("Invalid physical calibration draw ",i,
             "; reduce declared uncertainty or inspect geometry",
             call.=FALSE)
      perturbed_cams[[j]] <- aqt_flatport_camera(
        original$K,original$R_c2w,center=centre,
        glass_front_point=original$plane_point,
        glass_normal=original$plane_normal,
        glass_thickness=thickness,
        n_first=original$n_before,n_glass=ng,n_water=nw,
        units=original$units)
      d <- as.data.frame(source_views[[j]])
      d$x <- d$x+stats::rnorm(nrow(d),sd=pixel_sd[j])
      d$y <- d$y+stats::rnorm(nrow(d),sd=pixel_sd[j])
      perturbed_views[[j]] <- aqt_tracks(
        d,units="px",coordinate_system="image")
    }
    xyz <- tryCatch(
      aqt_refractive_reconstruct_tracks(
        perturbed_views[[1]],perturbed_views[[2]],
        correspondences,perturbed_cams[[1]],perturbed_cams[[2]],
        max_skew_s=max_skew_s,
        max_ray_separation=max_ray_separation),
      error=function(e) stop("Joint optical scenario ",i,
                             " failed: ",conditionMessage(e),
                             call.=FALSE))
    nselected <- 0L
    if (!is.null(identity_events) && nrow(identity_events)) {
      id <- aqt_identity_switch_scenarios(
        xyz,identity_events,draws=1L,
        seed=as.integer((seed+i) %% 2147483001))
      xyz <- aqt_identity_draw(id,1L)
      nselected <- length(attr(xyz,"aqt_identity_selected_events"))
    }
    qc <- aqt_refractive_track_quality(xyz)
    paths[[i]] <- xyz
    calibration[[i]] <- data.frame(draw=i,
      center_a_x=perturbed_cams[[1]]$center[1L],
      center_a_y=perturbed_cams[[1]]$center[2L],
      center_a_z=perturbed_cams[[1]]$center[3L],
      center_b_x=perturbed_cams[[2]]$center[1L],
      center_b_y=perturbed_cams[[2]]$center[2L],
      center_b_z=perturbed_cams[[2]]$center[3L],
      thickness_a=perturbed_cams[[1]]$glass_thickness,
      thickness_b=perturbed_cams[[2]]$glass_thickness,
      glass_index_a=perturbed_cams[[1]]$n_after,
      glass_index_b=perturbed_cams[[2]]$n_after,
      water_index_a=perturbed_cams[[1]]$n_water,
      water_index_b=perturbed_cams[[2]]$n_water)
    quality[[i]] <- data.frame(draw=i,
       n_valid=sum(qc$n_valid),n_pairs=sum(qc$n_pairs),
       max_ray_separation=max(qc$max_separation,na.rm=TRUE),
       n_selected_identity_swaps=nselected)
  }
  structure(list(tracks=paths,
    calibration_draws=do.call(rbind,calibration),
    quality=do.call(rbind,quality),
    assumptions=list(pixel_sd=pixel_sd,center_sd=center_sd,
      glass_thickness_sd=glass_thickness_sd,
      n_glass_sd=n_glass_sd,n_water_sd=n_water_sd,
      draws=as.integer(draws),seed=as.integer(seed),
      identity_events=identity_events,
      probabilities_calibrated=FALSE,
      optical_parameters_calibrated=FALSE,
      uncertainty_interval_calibrated=FALSE,
      cross_view_identity_fixed=TRUE)),
    class="aqt_joint_refractive_scenarios")
}

#' Recalculate event-aligned fish behaviour for every joint optical/ID draw
#'
#' No video frames are treated as independent experimental replicates.
#' @param scenarios aqt_joint_refractive_scenarios.
#' @param events External event log.
#' @param outcome Numeric kinematic outcome such as speed.
#' @param windows Named event-relative nonoverlapping intervals.
#' @param unit_cols Columns identifying observational units.
#' @param max_gap_s Largest permissible movement segment.
#' @return Long conditional per-draw event epoch outcomes.
#' @export
aqt_joint_event_sensitivity <- function(
    scenarios,events,outcome="speed",
    windows=list(baseline=c(-3,0),response=c(0,3)),
    unit_cols=c("camera_id","track_id"),
    max_gap_s=Inf) {
  if (!inherits(scenarios,"aqt_joint_refractive_scenarios") ||
      !is.list(scenarios$tracks))
    stop("Expected joint refractive scenarios",call.=FALSE)
  out <- lapply(seq_along(scenarios$tracks),function(i) {
    d <- aqt_kinematics(scenarios$tracks[[i]],max_gap_s=max_gap_s)
    epoch <- aqt_event_epoch_summary(d,events,
      outcome=outcome,windows=windows,unit_cols=unit_cols,
      max_gap_s=max_gap_s)
    if (!nrow(epoch)) return(NULL)
    epoch$draw <- i
    epoch
  })
  out <- Filter(Negate(is.null),out)
  if (!length(out)) return(data.frame())
  result <- do.call(rbind,unname(out))
  rownames(result) <- NULL
  result
}

#' Compare tank-level event contrasts under joint optical/identity scenarios
#'
#' Reports one tank-replicated treatment contrast PER measurement scenario,
#' plus separate within-scenario bootstrap intervals based on resampled
#' independently treated tanks. The distribution across scenarios is a
#' CONDITIONAL SENSITIVITY interval, not a validated combined confidence
#' interval or causal estimate.
#'
#' @param scenarios Joint optical/ID uncertainty object.
#' @param events External event log.
#' @param windows Baseline and response windows.
#' @param outcome Kinematic outcome.
#' @param tank_bootstrap_draws Replications >= 100 per scenario.
#' @param seed Bootstrap seed, independent of optical/ID draw seed.
#' @return List of per-scenario tank contrasts and conditional quantiles.
#' @export
aqt_joint_tank_sensitivity <- function(
    scenarios,events,outcome="speed",
    windows=list(baseline=c(-3,0),response=c(0,3)),
    tank_bootstrap_draws=100L,seed=103L) {
  if (!inherits(scenarios,"aqt_joint_refractive_scenarios"))
    stop("Expected joint refractive scenarios",call.=FALSE)
  if (!all(vapply(scenarios$tracks,function(d)
       all(c("tank_id","treatment") %in% names(d)),logical(1L))))
    stop("Joint tank analysis requires matched tank_id/treatment metadata",
         call.=FALSE)
  epochs <- aqt_joint_event_sensitivity(scenarios,events,
    outcome=outcome,windows=windows,
    unit_cols=c("camera_id","track_id","tank_id","treatment"))
  if (!nrow(epochs)) stop("No estimable event outcomes",call.=FALSE)
  pieces <- lapply(split(epochs,epochs$draw),function(x) {
    fit <- aqt_tank_event_contrast(
      x,draws=tank_bootstrap_draws,
      seed=as.integer((seed+x$draw[1L]) %% 2147483001))
    data.frame(draw=as.integer(x$draw[1L]),
      contrast=fit$estimate,
      tank_bootstrap_lower=fit$lower,
      tank_bootstrap_upper=fit$upper,
      n_tanks_control=fit$n_tanks_control,
      n_tanks_treatment=fit$n_tanks_treatment)
  })
  result <- do.call(rbind,unname(pieces))
  rownames(result) <- NULL
  conditional <- unname(stats::quantile(result$contrast,
                        c(.025,.975)))
  list(per_draw=result,
    conditional_mean=mean(result$contrast),
    conditional_sd=stats::sd(result$contrast),
    conditional_95pct_range=conditional,
    treatment_causal=FALSE,
    calibrated_combined_interval=FALSE,
    interpretation="conditional optical/pixel/identity sensitivity; tank bootstrap separate")
}
