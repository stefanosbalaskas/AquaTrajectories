# Explicit Brown-Conrady (rational-free) perspective-lens model.
# NOT an omnidirectional/fisheye GoPro lens profile or empirical camera
# intrinsic/distortion calibration algorithm.

#' Define measured Brown-Conrady perspective lens distortion coefficients
#'
#' Maps normalized pinhole coordinates through radial k1,k2,k3 and
#' tangential p1,p2 terms. Requires an externally fitted camera K.
#' This model is NOT appropriate for unconverted GoPro fisheye/
#' superview/wide-angle source frames unless separately demonstrated.
#'
#' @param K Positive-focal-length pinhole intrinsic 3-by-3 matrix.
#' @param k1,k2,k3 Radial coefficients in normalized coordinate units.
#' @param p1,p2 Tangential coefficients.
#' @param max_normalized_radius Validated maximum normalized ray radius.
#' @return aqt_brown_camera with calibration_certified=FALSE.
#' @export
aqt_brown_camera <- function(K,k1=0,k2=0,p1=0,p2=0,k3=0,
                             max_normalized_radius=2) {
  if (!is.matrix(K) || !is.numeric(K) ||
      !identical(dim(K),c(3L,3L)) ||
      any(!is.finite(K)) ||
      max(abs(K[3L,]-c(0,0,1)))>1e-10 ||
      K[1L,1L]<=0 || K[2L,2L]<=0 ||
      abs(det(K))<1e-12)
    stop("K must be a positive-focal, invertible 3x3 intrinsic matrix",
         call.=FALSE)
  vals <- c(k1=k1,k2=k2,k3=k3,p1=p1,p2=p2)
  if (!is.numeric(vals) || length(vals)!=5L ||
      any(!is.finite(vals)))
    stop("Brown radial and tangential coefficients must be finite",
         call.=FALSE)
  if (!is.numeric(max_normalized_radius) ||
      length(max_normalized_radius)!=1L ||
      !is.finite(max_normalized_radius) ||
      max_normalized_radius<=0)
    stop("A finite positive validated normalized radius is required",
         call.=FALSE)
  structure(list(K=K,k1=k1,k2=k2,k3=k3,p1=p1,p2=p2,
    max_normalized_radius=max_normalized_radius,
    optical_model="Brown-Conrady perspective radial/tangential",
    calibration_certified=FALSE),
    class="aqt_brown_camera")
}

.aqt_brown_pixels <- function(pixels) {
  x <- as.matrix(pixels)
  if (!is.numeric(x) || ncol(x)!=2L ||
      any(is.infinite(x)))
    stop("Expected a numeric n-by-2 pixel matrix without infinities",
         call.=FALSE)
  x
}

.aqt_brown_normalize <- function(pixels,model) {
  y <- (pixels[,2L]-model$K[2L,3L])/model$K[2L,2L]
  x <- (pixels[,1L]-model$K[1L,3L]-model$K[1L,2L]*y)/
    model$K[1L,1L]
  cbind(x,y)
}

.aqt_brown_components <- function(x,y,model) {
  r2 <- x*x+y*y
  radial <- 1+model$k1*r2+model$k2*r2^2+model$k3*r2^3
  dx <- 2*model$p1*x*y+model$p2*(r2+2*x*x)
  dy <- model$p1*(r2+2*y*y)+2*model$p2*x*y
  list(radial=radial,dx=dx,dy=dy)
}

.aqt_brown_denormalize <- function(x,y,model) {
  data.frame(
    x_px=model$K[1L,1L]*x+model$K[1L,2L]*y+model$K[1L,3L],
    y_px=model$K[2L,2L]*y+model$K[2L,3L])
}

#' Apply a known Brown radial/tangential lens distortion model
#'
#' Forward-maps undistorted pinhole pixels into a modeled distorted
#' detector pixel domain, respecting the declared normalized FOV radius.
#' Rows with unknown coordinates remain invalid, not imputed.
#'
#' @param model aqt_brown_camera.
#' @param pixels Numeric n-by-2 undistorted pinhole coordinates.
#' @return Data frame distorted x_px,y_px,valid, not a fish track.
#' @export
aqt_brown_distort_pixels <- function(model,pixels) {
  if (!inherits(model,"aqt_brown_camera"))
    stop("Expected aqt_brown_camera",call.=FALSE)
  p <- .aqt_brown_pixels(pixels)
  out <- data.frame(x_px=rep(NA_real_,nrow(p)),
                    y_px=rep(NA_real_,nrow(p)),
                    valid=rep(FALSE,nrow(p)))
  if (!nrow(p))return(out)
  ok <- stats::complete.cases(p)
  if (!any(ok))return(out)
  z <- .aqt_brown_normalize(p[ok,,drop=FALSE],model)
  in_field <- rowSums(z*z) <= model$max_normalized_radius^2
  i <- which(ok)[in_field]
  if (!length(i))return(out)
  z <- z[in_field,,drop=FALSE]
  comp <- .aqt_brown_components(z[,1L],z[,2L],model)
  x <- z[,1L]*comp$radial+comp$dx
  y <- z[,2L]*comp$radial+comp$dy
  px <- .aqt_brown_denormalize(x,y,model)
  finite <- is.finite(px$x_px) & is.finite(px$y_px)
  out$x_px[i[finite]] <- px$x_px[finite]
  out$y_px[i[finite]] <- px$y_px[finite]
  out$valid[i[finite]] <- TRUE
  out
}

#' Invert a known Brown perspective lens distortion with residual QC
#'
#' Iteratively solves radial+tangential distortion for normalized
#' pinhole pixels. Non-converged or out-of-FOV observations remain
#' explicitly invalid; no invented coordinates are returned.
#'
#' @param model aqt_brown_camera with separately measured K and coefficients.
#' @param pixels Numeric n-by-2 distorted pixel matrix.
#' @param max_iter Integer 1..200 fixed-point iterations.
#' @param tolerance_norm Required normalized-coordinate step convergence.
#' @param max_roundtrip_px Maximum acceptable forward reprojection residual.
#' @return Data frame undistorted x_px/y_px, valid, iterations and
#'   forward roundtrip pixel error; calibration still not certified.
#' @export
aqt_brown_undistort_pixels <- function(
    model,pixels,max_iter=60L,tolerance_norm=1e-12,
    max_roundtrip_px=1e-5) {
  if (!inherits(model,"aqt_brown_camera"))
    stop("Expected aqt_brown_camera",call.=FALSE)
  p <- .aqt_brown_pixels(pixels)
  if (!is.numeric(max_iter) || length(max_iter)!=1L ||
      !is.finite(max_iter) || max_iter<1L ||
      max_iter>200L || max_iter!=floor(max_iter))
    stop("max_iter must be 1..200",call.=FALSE)
  for (v in list(tolerance_norm,max_roundtrip_px))
    if (!is.numeric(v) || length(v)!=1L ||
        !is.finite(v) || v<=0)
      stop("Undistortion thresholds must be positive finite values",
           call.=FALSE)
  out <- data.frame(x_px=rep(NA_real_,nrow(p)),
    y_px=rep(NA_real_,nrow(p)),
    valid=rep(FALSE,nrow(p)),
    iterations=rep(NA_integer_,nrow(p)),
    roundtrip_error_px=rep(NA_real_,nrow(p)))
  if (!nrow(p))return(out)
  for (i in seq_len(nrow(p))) {
    if (!all(is.finite(p[i,])))next
    target <- .aqt_brown_normalize(p[i,,drop=FALSE],model)
    xd <- target[1L,1L];yd <- target[1L,2L]
    x <- xd;y <- yd;converged <- FALSE
    for (j in seq_len(max_iter)) {
      comp <- .aqt_brown_components(x,y,model)
      if (!is.finite(comp$radial) ||
          abs(comp$radial)<1e-12)break
      nx <- (xd-comp$dx)/comp$radial
      ny <- (yd-comp$dy)/comp$radial
      if (!is.finite(nx) || !is.finite(ny) ||
          nx*nx+ny*ny>4*model$max_normalized_radius^2)break
      step <- max(abs(nx-x),abs(ny-y))
      x <- nx;y <- ny
      if (step<=tolerance_norm) {
        converged <- TRUE
        out$iterations[i] <- j
        break
      }
    }
    if (!converged ||
        x*x+y*y>model$max_normalized_radius^2)next
    back <- .aqt_brown_denormalize(x,y,model)
    projected <- .aqt_brown_components(x,y,model)
    roundtrip <- .aqt_brown_denormalize(
      x*projected$radial+projected$dx,
      y*projected$radial+projected$dy,model)
    err <- sqrt((roundtrip$x_px-p[i,1L])^2+
                (roundtrip$y_px-p[i,2L])^2)
    if (!is.finite(err) || err>max_roundtrip_px)next
    out$x_px[i] <- back$x_px
    out$y_px[i] <- back$y_px
    out$valid[i] <- TRUE
    out$roundtrip_error_px[i] <- err
  }
  out
}

#' Trace distorted camera pixels through a measured flat-port glass model
#'
#' Composes explicit Brown perspective undistortion with the separately
#' parameterized two-interface air-glass-water Snell model. Does not
#' certify parameters or infer correct cross-camera fish identities.
#'
#' @param camera aqt_flatport_camera.
#' @param lens aqt_brown_camera with exactly matching intrinsic K.
#' @param pixels Distorted n-by-2 source pixels; unknown rows are invalid.
#' @param ... Optional inversion thresholds passed to
#'   aqt_brown_undistort_pixels.
#' @return Underwater physical rays, undistortion validity and
#'   forward roundtrip pixel diagnostic, with invalid rays explicit.
#' @export
aqt_flatport_rays_distorted <- function(camera,lens,pixels,...) {
  if (!inherits(camera,"aqt_flatport_camera") ||
      !inherits(lens,"aqt_brown_camera"))
    stop("Expected a flatport camera and Brown perspective lens",
         call.=FALSE)
  if (!identical(dim(camera$K),dim(lens$K)) ||
      max(abs(camera$K-lens$K))>1e-9)
    stop("Brown lens and flatport camera must have identical intrinsics K",
         call.=FALSE)
  original <- .aqt_brown_pixels(pixels)
  u <- aqt_brown_undistort_pixels(lens,original,...)
  out <- data.frame(origin_x=rep(NA_real_,nrow(original)),
    origin_y=rep(NA_real_,nrow(original)),
    origin_z=rep(NA_real_,nrow(original)),
    dir_x=rep(NA_real_,nrow(original)),
    dir_y=rep(NA_real_,nrow(original)),
    dir_z=rep(NA_real_,nrow(original)),
    valid=rep(FALSE,nrow(original)))
  valid <- which(u$valid)
  if (length(valid)) {
    ray <- aqt_flatport_rays(camera,
      as.matrix(u[valid,c("x_px","y_px"),drop=FALSE]))
    out[valid,names(out)] <- ray[,names(out),drop=FALSE]
  }
  out$lens_undistortion_valid <- u$valid
  out$lens_roundtrip_error_px <- u$roundtrip_error_px
  out$undistorted_x_px <- u$x_px
  out$undistorted_y_px <- u$y_px
  attr(out,"aqt_units") <- camera$units
  attr(out,"aqt_lens_calibration_certified") <- FALSE
  out
}


#' Preserve tracker provenance while undistorting canonical fish video tracks
#'
#' Applies an externally fitted Brown perspective lens model to one
#' pixel-space aqt_tracks object, retaining exact original detector
#' pixels, timestamps, IDs and an explicit per-observation roundtrip
#' error. Unknown and invalid fish positions stay unobserved. The
#' resulting 2D pinhole pixels can enter the existing refractive
#' multi-camera reconstruction only after independent cross-view
#' identity and synchronization checks.
#'
#' @param tracks aqt_tracks in 2D image coordinates and px units.
#' @param lens aqt_brown_camera with camera-matched intrinsic K.
#' @param ... Inversion thresholds for aqt_brown_undistort_pixels().
#' @return aqt_tracks containing undistorted x/y and original measured
#'   detector pixels in distorted_x_px/distorted_y_px.
#' @export
aqt_brown_undistort_tracks <- function(tracks,lens,...) {
  aqt_tracks_validate(tracks)
  if (!identical(attr(tracks,"aqt_dimension"),2L) ||
      !identical(attr(tracks,"aqt_coordinate_system"),"image") ||
      !identical(attr(tracks,"aqt_units"),"px"))
    stop("Lens track correction requires 2D image pixel tracks",
         call.=FALSE)
  if (!inherits(lens,"aqt_brown_camera"))
    stop("Expected aqt_brown_camera for observed detector pixels",
         call.=FALSE)
  d <- as.data.frame(tracks)
  if (any(c("distorted_x_px","distorted_y_px") %in% names(d)))
    stop("Tracks already have a distorted-pixel source: refuse double correction",
         call.=FALSE)
  u <- aqt_brown_undistort_pixels(
    lens,as.matrix(d[,c("x","y"),drop=FALSE]),...)
  d$distorted_x_px <- d$x
  d$distorted_y_px <- d$y
  d$lens_undistortion_valid <- u$valid
  d$lens_roundtrip_error_px <- u$roundtrip_error_px
  d$observed <- d$observed & u$valid
  d$x <- u$x_px
  d$y <- u$y_px
  d$x[!d$observed] <- NA_real_
  d$y[!d$observed] <- NA_real_
  out <- aqt_tracks(d,units="px",coordinate_system="image")
  attr(out,"aqt_lens_calibration_certified") <- FALSE
  out
}
