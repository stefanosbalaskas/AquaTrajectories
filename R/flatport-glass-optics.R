#' Parameterize two parallel air-glass-water optical interfaces
#'
#' Models an undistorted perspective camera in the first medium facing
#' a measured parallel planar glass slab. Light is traced through
#' first medium -> glass -> target medium, obeying Snell's law at
#' BOTH boundaries. The camera orientation, intrinsics, interface
#' normal/point and glass thickness are externally supplied calibration
#' quantities. This does not fit them, validate real glass planarity or
#' correct lens/fisheye distortion, dome ports or rolling shutter.
#'
#' @param K Finite intrinsic matrix for UNDISTORTED source pixels.
#' @param R_c2w Proper camera-to-world rotation.
#' @param center Source camera optical centre in common world coordinates.
#' @param glass_front_point World-space point on camera-side glass surface.
#' @param glass_normal Normal from camera-side medium into glass and water.
#' @param glass_thickness Positive physical slab thickness along the normal.
#' @param n_first,n_glass,n_water Positive refractive indices.
#' @param units World units in cm or m.
#' @return aqt_flatport_camera with explicit two-interface model.
#' @export
aqt_flatport_camera <- function(K,R_c2w,center,glass_front_point,
                                glass_normal,glass_thickness,
                                n_first=1,n_glass=1.5,n_water=1.333,
                                units="cm") {
  camera <- aqt_refractive_camera(
    K,R_c2w,center,glass_front_point,glass_normal,
    n_before=n_first,n_after=n_glass,units=units)
  if (!is.numeric(glass_thickness) || length(glass_thickness)!=1L ||
      !is.finite(glass_thickness) || glass_thickness<=0)
    stop("glass_thickness must be positive in world units",call.=FALSE)
  if (!is.numeric(n_water) || length(n_water)!=1L ||
      !is.finite(n_water) || n_water<=0)
    stop("n_water must be positive and finite",call.=FALSE)
  camera$glass_thickness <- glass_thickness
  camera$n_water <- n_water
  camera$model <- "parallel_two_interface_flatport"
  camera$calibration_validated <- FALSE
  class(camera) <- c("aqt_flatport_camera","aqt_refraction_camera")
  camera
}

#' Trace source pixels through both surfaces of a flat aquarium glass wall
#'
#' The first surface is described by glass_front_point and glass_normal,
#' the second lies glass_thickness farther along the normal. The output
#' is a ray in the target (nominal water) medium. Invalid intersections
#' or total internal reflection remain explicit missing rays.
#'
#' @param camera An aqt_flatport_camera.
#' @param pixels Undistorted source-image n-by-2 pixel coordinates.
#' @return World-space water ray origins/directions and valid flags.
#' @export
aqt_flatport_rays <- function(camera,pixels) {
  if (!inherits(camera,"aqt_flatport_camera") ||
      !identical(camera$model,"parallel_two_interface_flatport"))
    stop("Expected a two-interface flatport camera",call.=FALSE)
  first <- camera
  class(first) <- "aqt_refraction_camera"
  first$model <- "single_ideal_planar_interface"
  glass_rays <- aqt_refractive_rays(first,pixels)
  ans <- glass_rays
  if (!nrow(ans)) return(ans)
  normal <- camera$plane_normal
  eta <- camera$n_after/camera$n_water
  for (i in seq_len(nrow(ans))) {
    if (!glass_rays$valid[i]) next
    start <- unlist(glass_rays[i,1:3],use.names=FALSE)
    incoming <- unlist(glass_rays[i,4:6],use.names=FALSE)
    incidence <- sum(incoming*normal)
    if (incidence<=1e-12) {
      ans[i,1:6] <- rep(NA_real_,6L)
      ans$valid[i] <- FALSE
      next
    }
    t <- camera$glass_thickness/incidence
    second_origin <- start+t*incoming
    transverse <- eta*(incoming-incidence*normal)
    sin2 <- sum(transverse^2)
    if (!is.finite(sin2) || sin2>=1) {
      ans[i,1:6] <- rep(NA_real_,6L)
      ans$valid[i] <- FALSE
      next
    }
    transmitted <- transverse+sqrt(1-sin2)*normal
    transmitted <- transmitted/sqrt(sum(transmitted^2))
    ans[i,1:3] <- as.list(second_origin)
    ans[i,4:6] <- as.list(transmitted)
  }
  attr(ans,"aqt_units") <- camera$units
  ans
}
