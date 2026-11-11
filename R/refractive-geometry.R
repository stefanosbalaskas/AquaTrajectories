# One-interface refraction only: two homogeneous media separated by one
# ideal planar surface, with known extrinsics and optics. A real glass port
# has at least two surfaces and must NOT be treated as this one-interface rig.

.aqt_ref_unit <- function(v, name) {
  if (!is.numeric(v) || length(v)!=3L || any(!is.finite(v)) ||
      sum(v*v)<=0) stop(name," must be a finite nonzero 3-vector",call.=FALSE)
  as.numeric(v)/sqrt(sum(v*v))
}
.aqt_ref_xyz <- function(x,name) {
  x <- as.matrix(x)
  if (!is.numeric(x) || ncol(x)!=3L ||
      any(!is.finite(x)))
    stop(name," must be a finite numeric n-by-3 matrix",call.=FALSE)
  x
}
.aqt_ref_px <- function(x) {
  x <- as.matrix(x)
  if (!is.numeric(x) || ncol(x)!=2L ||
      any(!is.finite(x)))
    stop("pixels must be finite numeric n-by-2",call.=FALSE)
  x
}

#' Define one calibrated ideal air-water planar refractive camera
#'
#' All parameters are user-supplied calibration quantities, NOT
#' automatically calibrated. This model applies to exactly one ideal
#' interface between two homogeneous media. It MUST NOT be used as a
#' physically exact model for flat glass windows (two interfaces),
#' dome ports, nonplanar surfaces, lens distortion or rolling shutter.
#'
#' @param K Finite invertible 3x3 camera intrinsic matrix with K[3,]=c(0,0,1).
#' @param R_c2w Rotation (camera-to-world) with orthonormal columns.
#' @param center Camera optical centre in world coordinates.
#' @param plane_point Point on the ideal planar optical interface.
#' @param plane_normal Unit direction from the camera-side medium to
#'   the target medium. It is normalized internally.
#' @param n_before,n_after Positive refractive indices of the two media.
#' @param units World-coordinate units, "cm" or "m".
#' @return An aqt_refraction_camera object.
#' @export
aqt_refractive_camera <- function(K,R_c2w,center,plane_point,plane_normal,
                                  n_before=1,n_after=1.333,units="cm") {
  if (!is.matrix(K) || !is.numeric(K) ||
      !identical(dim(K),c(3L,3L)) || any(!is.finite(K)) ||
      !isTRUE(all.equal(unname(K[3L,]),c(0,0,1),tolerance=1e-10)) ||
      K[1,1]<=0 || K[2,2]<=0 || abs(det(K))<1e-12)
    stop("K must be a valid finite 3x3 camera intrinsic matrix",call.=FALSE)
  if (!is.matrix(R_c2w) || !is.numeric(R_c2w) ||
      !identical(dim(R_c2w),c(3L,3L)) ||
      any(!is.finite(R_c2w)) ||
      max(abs(crossprod(R_c2w)-diag(3)))>1e-6 ||
      det(R_c2w)<.9999)
    stop("R_c2w must be a proper orthonormal rotation",call.=FALSE)
  if (!is.numeric(center) || length(center)!=3L ||
      !is.numeric(plane_point) || length(plane_point)!=3L ||
      any(!is.finite(center)) || any(!is.finite(plane_point)))
    stop("center and plane_point must be finite 3-vectors",call.=FALSE)
  n <- .aqt_ref_unit(plane_normal,"plane_normal")
  if (sum((plane_point-center)*n)<=1e-10)
    stop("Camera must be in front of the medium-facing interface plane",call.=FALSE)
  if (!is.numeric(n_before) || !is.numeric(n_after) ||
      length(n_before)!=1L || length(n_after)!=1L ||
      !is.finite(n_before) || !is.finite(n_after) ||
      n_before<=0 || n_after<=0)
    stop("Refractive indices must be positive and finite",call.=FALSE)
  if (!is.character(units) || length(units)!=1L ||
      !units %in% c("cm","m"))
    stop("World units must be cm or m",call.=FALSE)
  structure(list(K=K,R_c2w=R_c2w,center=as.numeric(center),
    plane_point=as.numeric(plane_point),plane_normal=n,
    n_before=n_before,n_after=n_after,units=units,
    model="single_ideal_planar_interface",
    calibration_validated=FALSE),class="aqt_refraction_camera")
}

#' Trace image pixels through a single ideal planar refractive interface
#'
#' Ray directions follow vector Snell refraction and return ray origins
#' on the interface plus directions in the second homogeneous medium.
#' No automatic calibration, distortion or glass-thickness compensation.
#'
#' @param camera aqt_refraction_camera.
#' @param pixels Numeric n-by-2 observed undistorted pixel coordinates.
#' @return Data frame of refracted ray origin/direction and valid flag.
#' @export
aqt_refractive_rays <- function(camera,pixels) {
  if (inherits(camera,"aqt_flatport_camera"))
    return(aqt_flatport_rays(camera,pixels))
  if (!inherits(camera,"aqt_refraction_camera") ||
      !identical(camera$model,"single_ideal_planar_interface"))
    stop("Expected an ideal single-interface refractive camera",call.=FALSE)
  p <- .aqt_ref_px(pixels)
  nobs <- nrow(p)
  ans <- data.frame(origin_x=rep(NA_real_,nobs),
    origin_y=rep(NA_real_,nobs),origin_z=rep(NA_real_,nobs),
    dir_x=rep(NA_real_,nobs),dir_y=rep(NA_real_,nobs),
    dir_z=rep(NA_real_,nobs),valid=rep(FALSE,nobs))
  if (!nobs) return(ans)
  for (i in seq_len(nobs)) {
    h <- as.vector(solve(camera$K,c(p[i,1L],p[i,2L],1)))
    d <- .aqt_ref_unit(as.vector(camera$R_c2w %*% h),"pixel ray")
    normal <- camera$plane_normal
    incidence <- sum(d*normal)
    if (incidence<=1e-12) next
    t <- sum((camera$plane_point-camera$center)*normal)/incidence
    if (!is.finite(t) || t<=0) next
    eta <- camera$n_before/camera$n_after
    tangential <- d-incidence*normal
    scaled <- eta*tangential
    sin2 <- sum(scaled^2)
    if (sin2>=1) next  # total internal reflection / grazing
    refr <- scaled+sqrt(1-sin2)*normal
    surface <- camera$center+t*d
    ans[i,1:3] <- as.list(surface)
    ans[i,4:6] <- as.list(.aqt_ref_unit(refr,"refracted ray"))
    ans$valid[i] <- TRUE
  }
  attr(ans,"aqt_units") <- camera$units
  ans
}

#' Triangulate externally paired fish observations as underwater rays
#'
#' Finds the midpoint of shortest positive-length segments between
#' corresponding refracted rays, reporting separation error. This is
#' geometric triangulation, not automatic fish identity association.
#' Ray separation in physical units is a consistency diagnostic, not
#' independent position accuracy or statistical interval coverage.
#'
#' @param camera_a,camera_b Two compatible explicitly parameterized refractive cameras,
#'   with matching world-coordinate units.
#' @param pixels_a,pixels_b Explicitly corresponding undistorted n-by-2
#'   source-image pixel coordinates.
#' @param max_separation Optional nonnegative maximum ray separation in
#'   the camera's physical units; exceeding it invalidates an estimate.
#' @return XYZ midpoint, ray separation, ray parameters, and validity.
#' @export
aqt_refractive_triangulate <- function(camera_a,camera_b,pixels_a,pixels_b,
                                      max_separation=Inf) {
  a <- aqt_refractive_rays(camera_a,pixels_a)
  b <- aqt_refractive_rays(camera_b,pixels_b)
  if (nrow(a)!=nrow(b))
    stop("Two image views must contain the same number of paired points",
         call.=FALSE)
  if (!identical(camera_a$units,camera_b$units))
    stop("Refractive cameras must use common world units",call.=FALSE)
  if (!is.numeric(max_separation) || length(max_separation)!=1L ||
      is.na(max_separation) || max_separation<0)
    stop("max_separation must be nonnegative",call.=FALSE)
  n <- nrow(a)
  out <- data.frame(x=rep(NA_real_,n),y=rep(NA_real_,n),
    z=rep(NA_real_,n),separation=rep(NA_real_,n),
    distance_a=rep(NA_real_,n),distance_b=rep(NA_real_,n),
    valid=rep(FALSE,n))
  for (i in seq_len(n)) {
    if (!a$valid[i] || !b$valid[i]) next
    p <- unlist(a[i,1:3],use.names=FALSE); q <- unlist(b[i,1:3],use.names=FALSE)
    d <- unlist(a[i,4:6],use.names=FALSE); e <- unlist(b[i,4:6],use.names=FALSE)
    cross <- sum(d*e)
    denom <- 1-cross^2
    if (denom<=1e-10) next
    w <- p-q
    ud <- sum(w*d); ue <- sum(w*e)
    t <- (cross*ue-ud)/denom
    s <- (ue-cross*ud)/denom
    if (t<0 || s<0) next
    qa <- p+t*d; qb <- q+s*e
    err <- sqrt(sum((qa-qb)^2))
    out$separation[i] <- err
    out$distance_a[i] <- t
    out$distance_b[i] <- s
    if (err>max_separation) next
    out[i,1:3] <- as.list((qa+qb)/2)
    out$valid[i] <- TRUE
  }
  attr(out,"aqt_units") <- camera_a$units
  out
}

#' Compare manually verified underwater landmark positions with traced rays
#'
#' Measures minimum perpendicular distance between observed refracted rays
#' and independent 3D target landmarks. It is a physical consistency check,
#' not proof of calibration unless landmarks and their measurement accuracy
#' have been independently established.
#' @param camera aqt_refraction_camera.
#' @param pixels n-by-2 observed undistorted pixels of known landmarks.
#' @param landmarks_xyz Matched known n-by-3 world-space reference points.
#' @return Per-landmark perpendicular ray residual and summary RMSE.
#' @export
aqt_refractive_landmark_qc <- function(camera,pixels,landmarks_xyz) {
  rays <- aqt_refractive_rays(camera,pixels)
  world <- .aqt_ref_xyz(landmarks_xyz,"landmarks_xyz")
  if (nrow(rays)!=nrow(world))
    stop("Landmarks and source pixels must be paired",call.=FALSE)
  n <- nrow(rays)
  d <- rep(NA_real_,n)
  for (i in seq_len(n)) {
    if (!rays$valid[i]) next
    start <- unlist(rays[i,1:3],use.names=FALSE)
    dir <- unlist(rays[i,4:6],use.names=FALSE)
    relative <- world[i,]-start
    depth <- sum(relative*dir)
    if (depth<0) next
    d[i] <- sqrt(sum((relative-depth*dir)^2))
  }
  list(per_landmark=data.frame(index=seq_len(n),
    residual=d,valid=is.finite(d)),n_total=n,
    n_valid=sum(is.finite(d)),
    rmse=if (any(is.finite(d))) sqrt(mean(d[is.finite(d)]^2))
      else NA_real_,units=camera$units,
    calibration_certified=FALSE)
}
