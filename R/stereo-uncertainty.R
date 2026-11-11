# Preliminary conditional position-uncertainty calculations for known
# 2-camera correspondences. Monte Carlo intervals are NOT calibrated
# statistical confidence intervals and do NOT include calibration error,
# timestamp errors, missed animals, ID switches, or model misspecification.

#' Propagate assumed camera pixel localization noise into stereo XYZ
#'
#' This draws independent Gaussian X/Y errors for each image observation
#' (one scale per camera), then triangulates using fixed calibrated pinhole
#' projection matrices and *fixed known correspondences*. Derived intervals
#' are sensitivity intervals CONDITIONAL on the assumed pixel error model,
#' rig and identity assignments, not validated confidence intervals.
#'
#' @param xy1,xy2 Corresponding n-by-2 image-coordinate matrices.
#' @param P1,P2 Calibrated non-refractive 3-by-4 projection matrices.
#' @param sigma_px Pixel SD as a single nonnegative number or length-two
#'   camera-specific vector. Zero gives an exact deterministic baseline.
#' @param draws Number of Monte Carlo replicates, at least 20.
#' @param seed Random seed; does not modify global RNG state.
#' @param level Central fraction for equal-tailed Monte Carlo intervals.
#' @return Per-point estimate, XYZ standard deviations, covariance terms,
#'   equal-tail intervals, valid replicates and validity fraction.
#' @export
aqt_stereo_pixel_mc <- function(xy1,xy2,P1,P2,sigma_px=1,
                                draws=300L,seed=1001L,level=.95) {
  a <- as.matrix(xy1); b <- as.matrix(xy2)
  if (!is.numeric(a) || !is.numeric(b) ||
      ncol(a)!=2L || ncol(b)!=2L || nrow(a)!=nrow(b))
    stop("Expected corresponding n-by-2 numeric matrices",call.=FALSE)
  if (!is.numeric(sigma_px) || !length(sigma_px) ||
      length(sigma_px)>2L || any(!is.finite(sigma_px)) ||
      any(sigma_px<0))
    stop("sigma_px must be one or two finite nonnegative standard deviations",call.=FALSE)
  if (length(sigma_px)==1L) sigma_px <- rep(sigma_px,2L)
  if (length(draws)!=1L || !is.numeric(draws) || !is.finite(draws) ||
      draws<20 || draws!=floor(draws))
    stop("draws must be an integer >=20",call.=FALSE)
  if (length(seed)!=1L || !is.numeric(seed) || !is.finite(seed) ||
      seed!=floor(seed) || seed<0 || seed>2147483647)
    stop("seed must be a nonnegative 32-bit integer",call.=FALSE)
  if (length(level)!=1L || !is.numeric(level) || !is.finite(level) ||
      level<=0 || level>=1)
    stop("level must lie strictly between 0 and 1",call.=FALSE)
  if (nrow(a)*draws>1000000)
    stop("Monte Carlo sample cap exceeded; split into manageable windows",call.=FALSE)
  baseline <- aqt_triangulate_pairs(a,b,P1,P2)
  n <- nrow(a)
  result <- data.frame(point_index=seq_len(n),x=baseline$x,y=baseline$y,z=baseline$z,
    sd_x=rep(NA_real_,n),sd_y=rep(NA_real_,n),sd_z=rep(NA_real_,n),
    lower_x=rep(NA_real_,n),upper_x=rep(NA_real_,n),
    lower_y=rep(NA_real_,n),upper_y=rep(NA_real_,n),
    lower_z=rep(NA_real_,n),upper_z=rep(NA_real_,n),
    cov_xy=rep(NA_real_,n),cov_xz=rep(NA_real_,n),
    cov_yz=rep(NA_real_,n),n_valid_draws=integer(n),
    valid_fraction=rep(NA_real_,n))
  if (!n) return(result)
  had <- exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE)
  if (had) old <- get(".Random.seed",envir=.GlobalEnv)
  on.exit({
    if (had) assign(".Random.seed",old,envir=.GlobalEnv)
    else if (exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
      rm(".Random.seed",envir=.GlobalEnv)
  },add=TRUE)
  set.seed(as.integer(seed))
  ensemble <- array(NA_real_,dim=c(n,3L,as.integer(draws)))
  for (k in seq_len(draws)) {
    perturb_a <- matrix(stats::rnorm(n*2L,sd=sigma_px[1L]),ncol=2L)
    perturb_b <- matrix(stats::rnorm(n*2L,sd=sigma_px[2L]),ncol=2L)
    rec <- aqt_triangulate_pairs(a+perturb_a,b+perturb_b,P1,P2)
    ensemble[,,k] <- as.matrix(rec[,c("x","y","z"),drop=FALSE])
  }
  alpha <- (1-level)/2
  for (i in seq_len(n)) {
    sample <- t(ensemble[i,,,drop=TRUE])
    if (!is.matrix(sample)) sample <- matrix(sample,ncol=3L,byrow=TRUE)
    valid <- stats::complete.cases(sample)
    result$n_valid_draws[i] <- sum(valid)
    result$valid_fraction[i] <- mean(valid)
    if (sum(valid)<2L) next
    good <- sample[valid,,drop=FALSE]
    v <- apply(good,2L,stats::sd)
    bounds <- apply(good,2L,stats::quantile,probs=c(alpha,1-alpha),
                    na.rm=TRUE,names=FALSE)
    cv <- stats::cov(good)
    result[i,c("sd_x","sd_y","sd_z")] <- v
    result[i,c("lower_x","lower_y","lower_z")] <- bounds[1L,]
    result[i,c("upper_x","upper_y","upper_z")] <- bounds[2L,]
    result[i,c("cov_xy","cov_xz","cov_yz")] <-
      c(cv[1L,2L],cv[1L,3L],cv[2L,3L])
  }
  attr(result,"aqt_conditional_model") <- list(
    assumed_error="independent Gaussian camera image XY jitter",
    sigma_px=sigma_px,draws=draws,seed=seed,level=level,
    excludes=c("identity ambiguity","camera calibration uncertainty",
               "clock and exposure uncertainty","refraction",
               "biological sampling uncertainty"))
  result
}

#' Attach pixel-noise stereo uncertainty to a reconstructed 3D fish path
#'
#' This function requires raw 2D view observations, their verified
#' correspondences already stored in the reconstructed object, and its
#' original non-refractive camera rig. Returns the same 3D trajectories
#' with conditional uncertainty columns. Identity and calibration errors
#' remain excluded.
#'
#' @param reconstructed Output of aqt_reconstruct_3d().
#' @param view_a,view_b Original camera-local 2D tracks.
#' @param sigma_px Assumed camera-specific localization SD in pixels.
#' @param draws Number of Monte Carlo replicates.
#' @param seed Seed without changing external R random state.
#' @param level Equal-tail interval central mass.
#' @return 3D aqt_tracks with estimated conditional uncertainty fields.
#' @export
aqt_reconstruction_pixel_uncertainty <- function(
    reconstructed,view_a,view_b,sigma_px=1,draws=300L,seed=1001L,level=.95) {
  aqt_tracks_validate(reconstructed)
  aqt_tracks_validate(view_a); aqt_tracks_validate(view_b)
  if (!identical(attr(reconstructed,"aqt_dimension"),3L) ||
      !all(c("source_camera_a","source_camera_b",
             "source_id_a","source_id_b","time_a_s","time_b_s") %in%
           names(reconstructed)))
    stop("Expected aqt_reconstruct_3d output with source metadata",call.=FALSE)
  rig <- attr(reconstructed,"aqt_rig")
  aqt_rig_validate(rig)
  if (!identical(rig$optical_path,"air_only"))
    stop("Pixel Monte Carlo requires an explicitly nonrefractive rig",call.=FALSE)
  a <- as.data.frame(view_a); b <- as.data.frame(view_b)
  ca <- unique(a$camera_id); cb <- unique(b$camera_id)
  if (length(ca)!=1L || length(cb)!=1L ||
      any(reconstructed$source_camera_a!=ca) ||
      any(reconstructed$source_camera_b!=cb))
    stop("Camera data do not match reconstructed track provenance",call.=FALSE)
  ia <- match(.aqt_join_key(reconstructed$session_id,
       reconstructed$source_id_a,reconstructed$time_a_s),
       .aqt_join_key(a$session_id,a$track_id,a$time_s))
  ib <- match(.aqt_join_key(reconstructed$session_id,
       reconstructed$source_id_b,reconstructed$time_b_s),
       .aqt_join_key(b$session_id,b$track_id,b$time_s))
  if (anyNA(ia) || anyNA(ib))
    stop("Original camera observations are missing for uncertainty analysis",call.=FALSE)
  xa <- as.matrix(a[ia,c("x","y"),drop=FALSE])
  xb <- as.matrix(b[ib,c("x","y"),drop=FALSE])
  valid <- reconstructed$observed & a$observed[ia] & b$observed[ib]
  xa[!valid,] <- NA_real_
  xb[!valid,] <- NA_real_
  mc <- aqt_stereo_pixel_mc(xa,xb,
    rig$projections[[ca]],rig$projections[[cb]],
    sigma_px=sigma_px,draws=draws,seed=seed,level=level)
  d <- as.data.frame(reconstructed)
  fields <- setdiff(names(mc),c("point_index","x","y","z"))
  d[fields] <- mc[fields]
  out <- aqt_tracks(d,units=attr(reconstructed,"aqt_units"),
                   coordinate_system="tank")
  attr(out,"aqt_rig") <- rig
  attr(out,"aqt_conditional_model") <- attr(mc,"aqt_conditional_model")
  out
}
