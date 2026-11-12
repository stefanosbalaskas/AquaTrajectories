# Brown-Conrady perspective-lens distortion of UNDISTORTED camera rays.
# Not fisheye, dome-port, rolling-shutter or underwater auto-calibration.

.aqt_brown_validate <- function(K,coefficients) {
  if (!is.matrix(K) || !is.numeric(K) ||
      !identical(dim(K),c(3L,3L)) || any(!is.finite(K)) ||
      K[1L,1L]<=0 || K[2L,2L]<=0 ||
      abs(det(K))<1e-12 ||
      max(abs(K[3L,]-c(0,0,1)))>1e-10)
    stop("K must be a valid perspective 3x3 camera intrinsic matrix",
         call.=FALSE)
  expected <- c("k1","k2","p1","p2","k3")
  if (!is.numeric(coefficients) ||
      length(coefficients)!=5L ||
      is.null(names(coefficients)) ||
      !setequal(names(coefficients),expected) ||
      anyDuplicated(names(coefficients)) ||
      any(!is.finite(coefficients)))
    stop("coefficients must be named finite k1,k2,p1,p2,k3",
         call.=FALSE)
  as.numeric(coefficients[expected])
}

.aqt_brown_normalize <- function(px,K) {
  normalized <- t(solve(K,t(cbind(px,1))))
  normalized[,1:2,drop=FALSE] / normalized[,3L]
}

.aqt_brown_pixelize <- function(xy,K) {
  h <- t(K%*%t(cbind(xy,1)))
  h[,1:2,drop=FALSE]/h[,3L]
}

.aqt_brown_forward_normalized <- function(xy,co) {
  x <- xy[,1L];y <- xy[,2L]
  r2 <- x*x+y*y
  radial <- 1+co[1L]*r2+co[2L]*r2^2+co[5L]*r2^3
  if (any(!is.finite(radial)) || any(radial<=0))
    stop("Nonphysical radial distortion at requested image coordinates",
         call.=FALSE)
  tx <- 2*co[3L]*x*y+co[4L]*(r2+2*x*x)
  ty <- co[3L]*(r2+2*y*y)+2*co[4L]*x*y
  cbind(x=x*radial+tx,y=y*radial+ty)
}

#' Forward Brown-Conrady radial and tangential lens pixel distortion
#'
#' Applies five known calibrated coefficients to ideal pinhole pixels
#' using conventional normalized coordinates k1,k2,p1,p2,k3.
#' Does NOT estimate coefficients, correct underwater refraction,
#' or model fish-eye/dome lenses.
#'
#' @param pixels Finite numeric n-by-2 ideal undistorted pixels.
#' @param K Known calibrated 3x3 perspective camera intrinsics.
#' @param coefficients Named finite vector k1,k2,p1,p2,k3.
#' @return n-by-2 distorted camera pixel matrix.
#' @export
aqt_brown_distort_pixels <- function(pixels,K,coefficients) {
  p <- .aqt_ref_px(pixels)
  co <- .aqt_brown_validate(K,coefficients)
  if (!nrow(p))return(p)
  .aqt_brown_pixelize(.aqt_brown_forward_normalized(
    .aqt_brown_normalize(p,K),co),K)
}

#' Numerically undistort Brown-Conrady perspective camera image points
#'
#' Inverts the known radial/tangential forward mapping by fixed-point
#' iterations on normalized image coordinates. Rejects nonconvergence
#' and nonphysical radial factors. User must independently measure K
#' and coefficients. This is *not* valid for an arbitrary fisheye/GoPro
#' lens unless its own calibration establishes this exact model.
#'
#' @param pixels Finite numeric n-by-2 measured/distorted pixels.
#' @param K Known calibrated 3x3 perspective camera intrinsics.
#' @param coefficients Named finite vector k1,k2,p1,p2,k3.
#' @param max_iter Positive integer 1..200.
#' @param tolerance Positive normalized-coordinate residual tolerance.
#' @return n-by-2 undistorted pixels for subsequent refractive rays.
#' @export
aqt_brown_undistort_pixels <- function(pixels,K,coefficients,
                                      max_iter=60L,tolerance=1e-11) {
  p <- .aqt_ref_px(pixels)
  co <- .aqt_brown_validate(K,coefficients)
  if (!is.numeric(max_iter) || length(max_iter)!=1L ||
      !is.finite(max_iter) || max_iter!=floor(max_iter) ||
      max_iter<1 || max_iter>200)
    stop("max_iter must be an integer 1..200",call.=FALSE)
  if (!is.numeric(tolerance) || length(tolerance)!=1L ||
      !is.finite(tolerance) || tolerance<=0 || tolerance>=.01)
    stop("tolerance must be a positive small normalized-coordinate value",
         call.=FALSE)
  if (!nrow(p))return(p)
  xd <- .aqt_brown_normalize(p,K)
  xy <- xd
  converged <- FALSE
  for (iter in seq_len(max_iter)) {
    x <- xy[,1L];y <- xy[,2L]
    r2 <- x*x+y*y
    radial <- 1+co[1L]*r2+co[2L]*r2^2+co[5L]*r2^3
    if(any(!is.finite(radial)) || any(radial<=0))
      stop("Nonphysical radial factor during undistortion",call.=FALSE)
    tx <- 2*co[3L]*x*y+co[4L]*(r2+2*x*x)
    ty <- co[3L]*(r2+2*y*y)+2*co[4L]*x*y
    new <- cbind((xd[,1L]-tx)/radial,
                 (xd[,2L]-ty)/radial)
    if(any(!is.finite(new)) || any(abs(new)>100))
      stop("Lens undistortion diverged",call.=FALSE)
    xy <- new
    reconstruction <- .aqt_brown_forward_normalized(xy,co)
    if(max(abs(reconstruction-xd))<=tolerance) {
      converged <- TRUE
      break
    }
  }
  if(!converged)
    stop("Brown lens undistortion did not converge under declared tolerance",
         call.=FALSE)
  .aqt_brown_pixelize(xy,K)
}

#' Undistort observed 2D fish tracking positions using known lens parameters
#'
#' Missing or not-observed tracking points remain missing. All other
#' tracker metadata and IDs are retained. Downstream refraction routines
#' can consume this validated 2D image-space aqt_tracks object.
#'
#' @param tracks aqt_tracks with 2D pixel image coordinates.
#' @param K Known calibrated intrinsics of the source camera.
#' @param coefficients Named calibrated k1,k2,p1,p2,k3.
#' @param max_iter,tolerance Numerical solver settings.
#' @return aqt_tracks with pixel-undistortion provenance attributes.
#' @export
aqt_brown_undistort_tracks <- function(tracks,K,coefficients,
                                       max_iter=60L,tolerance=1e-11) {
  aqt_tracks_validate(tracks)
  if (!identical(attr(tracks,"aqt_dimension"),2L) ||
      !identical(attr(tracks,"aqt_coordinate_system"),"image") ||
      !identical(attr(tracks,"aqt_units"),"px"))
    stop("Brown lens correction requires 2D image/pixel tracks",
         call.=FALSE)
  co <- .aqt_brown_validate(K,coefficients)
  d <- as.data.frame(tracks)
  valid <- d$observed & stats::complete.cases(d[,c("x","y")])
  d$x[!valid] <- NA_real_
  d$y[!valid] <- NA_real_
  if (any(valid)) {
    xy <- aqt_brown_undistort_pixels(
      as.matrix(d[valid,c("x","y"),drop=FALSE]),
      K,coefficients,max_iter=max_iter,tolerance=tolerance)
    d[valid,c("x","y")] <- xy
  }
  out <- aqt_tracks(d,units="px",coordinate_system="image")
  attr(out,"aqt_distortion_model") <- "Brown-Conrady perspective (not fisheye)"
  attr(out,"aqt_distortion_coefficients") <- stats::setNames(
    co,c("k1","k2","p1","p2","k3"))
  attr(out,"aqt_undistortion_calibrated") <- FALSE
  out
}
