# Physical underwater landmark benchmarks for flat-port systems.
# These functions DO NOT declare measured camera parameters calibrated.

.aqt_landmark_idx <- function(x,n,name,min_n) {
  if (!is.numeric(x) || length(x)<min_n ||
      any(!is.finite(x)) || any(x<1 | x>n) ||
      any(x!=floor(x)) || anyDuplicated(x))
    stop(name," must have at least ",min_n,
         " distinct valid landmark indices",call.=FALSE)
  as.integer(x)
}

#' Evaluate refractive stereo coordinates against independent physical truth
#'
#' Unlike minimum ray separation, this reports absolute differences from
#' externally measured 3D landmark positions. Failed triangulations are
#' always included in the denominator and marked invalid.
#'
#' @param camera_a,camera_b Compatible refractive camera models.
#' @param pixels_a,pixels_b Matched undistorted n-by-2 camera pixel matrices.
#' @param landmarks_xyz Independently measured n-by-3 physical XYZ matrix.
#' @param landmark_id Optional unique landmark identifiers, n elements.
#' @param max_separation Maximum allowed closest-ray distance in physical
#'   camera units.
#' @return Per-landmark XYZ error and physical RMSE, MAE, bias, missingness,
#'   valid count and independent-truth diagnostics.
#' @export
aqt_stereo_landmark_benchmark <- function(
    camera_a,camera_b,pixels_a,pixels_b,landmarks_xyz,
    landmark_id=NULL,max_separation=Inf) {
  px_a <- .aqt_ref_px(pixels_a)
  px_b <- .aqt_ref_px(pixels_b)
  truth <- .aqt_ref_xyz(landmarks_xyz,"landmarks_xyz")
  n <- nrow(truth)
  if (n<3L || nrow(px_a)!=n || nrow(px_b)!=n)
    stop("Require >=3 paired image/independent physical landmarks",
         call.=FALSE)
  if (is.null(landmark_id))
    landmark_id <- paste0("L",seq_len(n))
  if (length(landmark_id)!=n || anyNA(landmark_id) ||
      any(!nzchar(as.character(landmark_id))) ||
      anyDuplicated(as.character(landmark_id)))
    stop("landmark_id must contain unique nonmissing IDs",call.=FALSE)
  tri <- aqt_refractive_triangulate(
    camera_a,camera_b,px_a,px_b,max_separation=max_separation)
  ok <- tri$valid & stats::complete.cases(tri[,c("x","y","z")])
  dx <- dy <- dz <- distance <- rep(NA_real_,n)
  if (any(ok)) {
    dx[ok] <- tri$x[ok]-truth[ok,1]
    dy[ok] <- tri$y[ok]-truth[ok,2]
    dz[ok] <- tri$z[ok]-truth[ok,3]
    distance[ok] <- sqrt(dx[ok]^2+dy[ok]^2+dz[ok]^2)
  }
  detail <- data.frame(
    landmark_id=as.character(landmark_id),
    truth_x=truth[,1],truth_y=truth[,2],truth_z=truth[,3],
    reconstructed_x=tri$x,reconstructed_y=tri$y,reconstructed_z=tri$z,
    error_x=dx,error_y=dy,error_z=dz,error_3d=distance,
    ray_separation=tri$separation,valid=ok,stringsAsFactors=FALSE)
  summary <- data.frame(n_total=n,n_valid=sum(ok),
    valid_fraction=mean(ok),n_invalid=sum(!ok),
    rmse_3d=if(any(ok))sqrt(mean(distance[ok]^2)) else NA_real_,
    mae_3d=if(any(ok))mean(distance[ok]) else NA_real_,
    max_error_3d=if(any(ok))max(distance[ok]) else NA_real_,
    rmse_x=if(any(ok))sqrt(mean(dx[ok]^2)) else NA_real_,
    rmse_y=if(any(ok))sqrt(mean(dy[ok]^2)) else NA_real_,
    rmse_z=if(any(ok))sqrt(mean(dz[ok]^2)) else NA_real_,
    bias_x=if(any(ok))mean(dx[ok]) else NA_real_,
    bias_y=if(any(ok))mean(dy[ok]) else NA_real_,
    bias_z=if(any(ok))mean(dz[ok]) else NA_real_)
  structure(list(per_landmark=detail,summary=summary,
    units=camera_a$units,
    truth_independent_assumed=TRUE,calibration_certified=FALSE,
    interpretation="absolute residuals against supplied physical reference"),
    class="aqt_stereo_landmark_benchmark")
}

#' Refine flat-port camera translation using measured 3D landmarks
#'
#' Optimizes ONLY the 3D camera optical centre, holding supplied camera
#' intrinsics, rotation, both parallel glass interfaces, thickness and
#' refractive indices fixed. Training and holdout landmarks must be
#' explicitly disjoint; independent holdout residuals remain visible.
#' This does not estimate full underwater calibration or uncertainty.
#'
#' @param camera A physically parameterized aqt_flatport_camera.
#' @param pixels n-by-2 undistorted image coordinates of external targets.
#' @param landmarks_xyz n-by-3 independently surveyed world coordinates.
#' @param training,holdout Disjoint index vectors; >=6 training,
#'   >=2 holdout landmarks. Do not repeat an identical target in both.
#' @param max_center_shift Maximum coordinate-wise change in physical units.
#' @param maxit Maximum optimizer iterations.
#' @return Refined camera, full fit diagnostics and heldout physical error.
#' @export
aqt_flatport_refine_center <- function(camera,pixels,landmarks_xyz,
                                       training,holdout,
                                       max_center_shift=.25,
                                       maxit=500L) {
  if (!inherits(camera,"aqt_flatport_camera"))
    stop("A two-interface flatport camera is required",call.=FALSE)
  px <- .aqt_ref_px(pixels)
  xyz <- .aqt_ref_xyz(landmarks_xyz,"landmarks_xyz")
  n <- nrow(xyz)
  if (nrow(px)!=n || n<8L)
    stop("Require at least eight paired physical landmarks",call.=FALSE)
  train <- .aqt_landmark_idx(training,n,"training",6L)
  test <- .aqt_landmark_idx(holdout,n,"holdout",2L)
  if (any(train %in% test))
    stop("Training and holdout landmarks must be disjoint",call.=FALSE)
  if (length(unique(round(xyz[train,3L],8)))<2L)
    stop("Training landmarks require variation in 3D depth",call.=FALSE)
  if (any(!is.finite(xyz)) ||
      any(as.vector((xyz-matrix(camera$plane_point,n,3,byrow=TRUE)) %*%
           camera$plane_normal)<=camera$glass_thickness))
    stop("Known physical landmarks must lie beyond the glass in the target medium",
         call.=FALSE)
  if (!is.numeric(max_center_shift) ||
      length(max_center_shift)!=1L ||
      !is.finite(max_center_shift) || max_center_shift<=0)
    stop("max_center_shift must be a positive physical bound",call.=FALSE)
  if (!is.numeric(maxit) || length(maxit)!=1L ||
      !is.finite(maxit) || maxit<20 ||
      maxit!=floor(maxit))
    stop("maxit must be an integer >=20",call.=FALSE)
  initial <- camera$center
  remake <- function(center) {
    aqt_flatport_camera(camera$K,camera$R_c2w,center=center,
      glass_front_point=camera$plane_point,
      glass_normal=camera$plane_normal,
      glass_thickness=camera$glass_thickness,
      n_first=camera$n_before,n_glass=camera$n_after,
      n_water=camera$n_water,units=camera$units)
  }
  evaluate <- function(c,idx) {
    qc <- aqt_refractive_landmark_qc(c,px[idx,,drop=FALSE],
                                     xyz[idx,,drop=FALSE])
    if (qc$n_valid!=length(idx) || !is.finite(qc$rmse))
      return(NA_real_)
    qc$rmse
  }
  objective <- function(offset) {
    new <- tryCatch(remake(initial+offset),error=function(e)NULL)
    if (is.null(new))return(1e20)
    value <- evaluate(new,train)
    if (!is.finite(value))return(1e20)
    value^2
  }
  initial_train <- evaluate(camera,train)
  initial_test <- evaluate(camera,test)
  if (!is.finite(initial_train) || !is.finite(initial_test))
    stop("Initial camera does not see all reviewed landmarks",call.=FALSE)
  fit <- stats::optim(par=c(0,0,0),fn=objective,
    method="L-BFGS-B",
    lower=rep(-max_center_shift,3L),
    upper=rep(max_center_shift,3L),
    control=list(maxit=as.integer(maxit)))
  refined <- remake(initial+fit$par)
  final_train <- evaluate(refined,train)
  final_test <- evaluate(refined,test)
  if (!is.finite(final_train) || !is.finite(final_test))
    stop("Fitted camera no longer sees all heldout physical targets",
         call.=FALSE)
  list(camera=refined,
    calibration_parameters="translation_only",
    original_center=initial,
    fitted_center=refined$center,
    center_adjustment=fit$par,
    training_n=length(train),holdout_n=length(test),
    train_rmse_before=initial_train,
    train_rmse_after=final_train,
    holdout_rmse_before=initial_test,
    holdout_rmse_after=final_test,
    convergence=fit$convergence,
    optimizer_message=if(is.null(fit$message))"" else fit$message,
    optimization_objective=fit$value,
    heldout_independence_requires_external_design=TRUE,
    calibration_certified=FALSE,
    units=camera$units)
}

#' Summarize 3D reconstruction accuracy across prespecified tank depths
#'
#' Uses true measured Z to classify depth ranges, not reconstructed Z;
#' reports coverage and RMSE separately in each range.
#'
#' @param benchmark aqt_stereo_landmark_benchmark.
#' @param depth_breaks Increasing physical Z cutpoints including all
#'   reference landmarks; at least two intervals.
#' @return Depth-group calibration accuracy and invalidity.
#' @export
aqt_stereo_depth_audit <- function(benchmark,depth_breaks) {
  if (!inherits(benchmark,"aqt_stereo_landmark_benchmark"))
    stop("Expected aqt_stereo_landmark_benchmark",call.=FALSE)
  if (!is.numeric(depth_breaks) || length(depth_breaks)<3L ||
      anyNA(depth_breaks) || any(diff(depth_breaks)<=0))
    stop("depth_breaks must be strictly increasing physical depths",
         call.=FALSE)
  d <- benchmark$per_landmark
  intervals <- cut(d$truth_z,breaks=depth_breaks,include.lowest=TRUE)
  if (anyNA(intervals))
    stop("Depth breaks must encompass all independently measured landmarks",
         call.=FALSE)
  groups <- split(seq_len(nrow(d)),intervals)
  result <- lapply(seq_along(groups),function(i) {
    idx <- groups[[i]]
    x <- d[idx,,drop=FALSE]
    valid <- x$valid
    data.frame(depth_interval=names(groups)[i],
      n_reference=nrow(x),n_valid=sum(valid),
      valid_fraction=mean(valid),
      rmse_3d=if(any(valid))
        sqrt(mean(x$error_3d[valid]^2)) else NA_real_,
      max_3d_error=if(any(valid))
        max(x$error_3d[valid]) else NA_real_)
  })
  out <- do.call(rbind,unname(result))
  rownames(out) <- NULL
  out
}
