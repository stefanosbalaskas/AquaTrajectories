# Wave 11C: independently surveyed underwater reference targets.
# Data validation and holdout scoring, NOT automatic calibration fitting.

#' Validate an independently measured underwater stereo target experiment
#'
#' Every trial contains externally measured physical XYZ and matching
#' undistorted 2D pixel observations in two cameras. Fit/holdout boards
#' must be disjoint in each trial to reduce same-board leakage.
#' The caller remains responsible for camera lens/refraction calibration,
#' actual physical landmark surveying and independent target collection.
#'
#' @param data One row per target with trial_id,tank_id,session_id,
#'   camera_a_id,camera_b_id,target_id,target_group,partition,
#'   truth_x,truth_y,truth_z,a_u_px,a_v_px,b_u_px,b_v_px.
#'   partition is fit or holdout. All pixels must already be correctly
#'   undistorted for the corresponding camera model.
#' @param units Physical world XYZ units cm or m.
#' @return aqt_target_trials with explicit physical and external-truth
#'   qualification flags.
#' @export
aqt_target_trial_table <- function(data,units=c("cm","m")) {
  units <- match.arg(units)
  ids <- c("trial_id","tank_id","session_id","camera_a_id","camera_b_id",
           "target_id","target_group","partition")
  coords <- c("truth_x","truth_y","truth_z",
              "a_u_px","a_v_px","b_u_px","b_v_px")
  if (!is.data.frame(data) || !nrow(data) ||
      !all(c(ids,coords) %in% names(data)))
    stop("Expected nonempty measured XYZ and paired undistorted target pixels",
         call.=FALSE)
  d <- as.data.frame(data,stringsAsFactors=FALSE)
  for (nm in ids) {
    v <- as.character(d[[nm]])
    if (anyNA(v) || any(!nzchar(trimws(v))))
      stop("Physical target identifiers and partition must be complete",
           call.=FALSE)
    d[[nm]] <- v
  }
  for (nm in coords)
    if (!is.numeric(d[[nm]]) || any(!is.finite(d[[nm]])))
      stop("Surveyed XYZ and undistorted pixel coordinates must be finite numeric",
           call.=FALSE)
  if (any(!d$partition %in% c("fit","holdout")))
    stop("Target partition must be fit or holdout",call.=FALSE)
  if (any(d$camera_a_id==d$camera_b_id))
    stop("Two distinct physical cameras required for every target",
         call.=FALSE)
  rows <- split(seq_len(nrow(d)),d$trial_id)
  for (idx in rows) {
    z <- d[idx,,drop=FALSE]
    for (name in c("tank_id","session_id","camera_a_id","camera_b_id"))
      if (length(unique(z[[name]]))!=1L)
        stop("Each trial must use one tank/session and fixed camera pair",
             call.=FALSE)
    if (anyDuplicated(z$target_id))
      stop("Duplicate physical target ID within a trial",call.=FALSE)
    xy <- z[,c("truth_x","truth_y","truth_z"),drop=FALSE]
    if (anyDuplicated(xy))
      stop("Repeated surveyed XYZ within one trial",call.=FALSE)
    train <- z[z$partition=="fit",,drop=FALSE]
    test <- z[z$partition=="holdout",,drop=FALSE]
    if (nrow(train)<6L || nrow(test)<3L)
      stop("Each trial requires >=6 fit and >=3 heldout surveyed landmarks",
           call.=FALSE)
    if (length(intersect(unique(train$target_group),
                         unique(test$target_group))))
      stop("Training and heldout target assemblies must be disjoint",
           call.=FALSE)
    if (length(unique(train$truth_z))<2L ||
        length(unique(test$truth_z))<2L)
      stop("Training and heldout references require depth variation",
           call.=FALSE)
  }
  d <- d[order(d$trial_id,d$partition,d$target_id),,drop=FALSE]
  rownames(d) <- NULL
  class(d) <- c("aqt_target_trials","data.frame")
  attr(d,"aqt_units") <- units
  attr(d,"aqt_pixel_contract") <- "externally_undistorted_image_pixels"
  attr(d,"aqt_external_xyz_survey_verified") <- FALSE
  attr(d,"aqt_calibration_certified") <- FALSE
  d
}

#' Benchmark underwater stereo models only on independent heldout targets
#'
#' Scores each externally supplied refractive camera pair against the
#' surveyed XYZ of holdout target assemblies; fit targets are NEVER used
#' in scoring. Per-trial denominators retain failed reconstructions.
#' Results do not prove the camera parameters were fitted without
#' leakage: model fitting, surveying quality and independent collection
#' remain external design responsibilities.
#'
#' @param targets An aqt_target_trials data frame.
#' @param cameras Named list mapping camera IDs to compatible
#'   aqt_refraction_camera models, with common physical units.
#' @param max_ray_separation Maximum valid ray-ray residual, in model units.
#' @return aqt_target_holdout_audit, per-trial accuracy, per-target errors,
#'   descriptive aggregate counts, without inflated target-level inference.
#' @export
aqt_target_holdout_benchmark <- function(
    targets,cameras,max_ray_separation=Inf) {
  if (!inherits(targets,"aqt_target_trials"))
    stop("Expected aqt_target_trials",call.=FALSE)
  units <- attr(targets,"aqt_units")
  d <- aqt_target_trial_table(as.data.frame(targets),units=units)
  if (!is.list(cameras) || length(cameras)<2L ||
      is.null(names(cameras)) ||
      anyNA(names(cameras)) || any(!nzchar(names(cameras))) ||
      anyDuplicated(names(cameras)) ||
      !all(vapply(cameras,function(x)
        inherits(x,"aqt_refraction_camera"),logical(1L))))
    stop("Provide named refractive camera models for each video view",
         call.=FALSE)
  if (any(vapply(cameras,function(x)
      !identical(x$units,units),logical(1L))))
    stop("Camera and independently surveyed XYZ units must match",
         call.=FALSE)
  if (!is.numeric(max_ray_separation) ||
      length(max_ray_separation)!=1L ||
      is.na(max_ray_separation) || max_ray_separation<0)
    stop("max_ray_separation must be nonnegative",call.=FALSE)
  groups <- split(seq_len(nrow(d)),d$trial_id)
  summaries <- vector("list",length(groups))
  details <- vector("list",length(groups))
  q <- 0L
  for (idx in groups) {
    z <- d[idx,,drop=FALSE]
    a <- z$camera_a_id[1L];b <- z$camera_b_id[1L]
    if (!all(c(a,b) %in% names(cameras)))
      stop("Missing camera model for a physical target trial",call.=FALSE)
    ca <- cameras[[a]]$center; cb <- cameras[[b]]$center
    if (is.numeric(ca) && is.numeric(cb) &&
        length(ca)==3L && length(cb)==3L &&
        all(is.finite(ca)) && all(is.finite(cb)) &&
        sqrt(sum((ca-cb)^2))<=1e-10)
      stop("Stereo models must have physically distinct camera centres",
           call.=FALSE)
    heldout <- z[z$partition=="holdout",,drop=FALSE]
    truth <- as.matrix(heldout[,c("truth_x","truth_y","truth_z")])
    xy_a <- as.matrix(heldout[,c("a_u_px","a_v_px")])
    xy_b <- as.matrix(heldout[,c("b_u_px","b_v_px")])
    bench <- aqt_stereo_landmark_benchmark(
      cameras[[a]],cameras[[b]],xy_a,xy_b,truth,
      landmark_id=heldout$target_id,
      max_separation=max_ray_separation)
    s <- bench$summary
    q <- q+1L
    summaries[[q]] <- data.frame(
      trial_id=z$trial_id[1L],tank_id=z$tank_id[1L],
      session_id=z$session_id[1L],
      camera_a_id=a,camera_b_id=b,
      n_fit_targets=sum(z$partition=="fit"),
      n_holdout_targets=s$n_total,
      n_valid=s$n_valid,n_invalid=s$n_invalid,
      valid_fraction=s$valid_fraction,
      rmse_3d=s$rmse_3d,mae_3d=s$mae_3d,
      max_error_3d=s$max_error_3d,
      rmse_x=s$rmse_x,rmse_y=s$rmse_y,rmse_z=s$rmse_z,
      bias_x=s$bias_x,bias_y=s$bias_y,bias_z=s$bias_z,
      stringsAsFactors=FALSE)
    dt <- bench$per_landmark
    dt$trial_id <- z$trial_id[1L]
    dt$tank_id <- z$tank_id[1L]
    dt$session_id <- z$session_id[1L]
    dt$camera_a_id <- a;dt$camera_b_id <- b
    dt$partition <- "holdout"
    details[[q]] <- dt
  }
  per_trial <- do.call(rbind,summaries)
  per_target <- do.call(rbind,details)
  rownames(per_trial) <- NULL;rownames(per_target) <- NULL
  valid <- per_target$valid & is.finite(per_target$error_3d)
  trial_rmse <- per_trial$rmse_3d[is.finite(per_trial$rmse_3d)]
  summary <- data.frame(
    n_trials=nrow(per_trial),
    n_tanks=length(unique(per_trial$tank_id)),
    n_heldout_targets=nrow(per_target),
    n_valid=sum(valid),
    n_invalid=sum(!valid),
    valid_fraction=mean(valid),
    mean_trial_rmse_3d=if(length(trial_rmse))mean(trial_rmse) else NA_real_,
    pooled_target_rmse_3d=if(any(valid))
      sqrt(mean(per_target$error_3d[valid]^2)) else NA_real_,
    units=units,stringsAsFactors=FALSE)
  structure(list(per_trial=per_trial,per_target=per_target,
    summary=summary,
    units=units,
    training_target_groups_not_scored=TRUE,
    independence_requires_external_collection=TRUE,
    source_xyz_survey_verified=FALSE,
    real_underwater_metrology_certified=FALSE,
    interpretation="conditional 3D residuals against externally supplied independent holdout target coordinates"),
    class="aqt_target_holdout_audit")
}
