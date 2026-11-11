# Wave 6A: ideal single-interface refractive camera geometry

## Supported optical model

AquaTrajectories now has a separately named, physically constrained
single-planar-interface ray-tracing primitive. It is for a hypothetical or
demonstrably calibrated TWO-MEDIUM setup separated by ONE PLANE.

- aqt_refractive_camera(): requires an externally estimated 3x3 intrinsic
  matrix, proper camera-to-world rotation, world-space camera centre,
  interface point, interface normal, refractive indices and world units.
  The camera must lie on the initial medium side of the declared plane.
- aqt_refractive_rays(): converts known undistorted 2D camera pixels into
  world-space ray origins on the plane and refracted unit directions
  using Snell's law. Invalid incoming rays and total internal reflection
  are flagged, never silently extrapolated.
- aqt_refractive_triangulate(): finds the closest points of independently
  matched forward refracted rays, returns their 3D midpoint, closest-ray
  separation and whether the solution meets declared physical tolerances.
- aqt_refractive_landmark_qc(): compares externally verified 3D world
  landmarks with the incoming pixel ray through the refractive surface.
  Perpendicular physical residuals and their RMSE are reported.

A known geometry test sets n_before=n_after=1, correctly recovering
standard perspective geometry. A second test uses n_before=1 and
n_after=4/3 to check physical ray bending and two-view reconstruction.

## IMPORTANT: no claim of full underwater camera calibration

The model DOES NOT handle a camera behind a flat glass port, because
the optics have AIR -> GLASS -> WATER transitions at two physical
surfaces. The model also does not handle dome ports, fish-eye lens
distortion, thick ports, curved glass, camera intrinsics optimization,
rolling shutter, wave-disturbed surfaces or time-varying refractive
indices.

Thus a GoPro recording through ordinary aquarium glass **cannot**
simply be declared a correctly modeled 'single interface'. User-provided
intrinsics and interface parameters are not proof of their accuracy.

Likewise, a small between-ray separation and low landmark ray residual
can indicate *geometric consistency*, not necessarily true-world 3D
accuracy, unless independent landmark measurements support that
conclusion. The function's 'calibration_certified' is always FALSE.

## Example: two direct single-surface cameras (mathematical fixture)

~~~r
library(aquaTrajectories)
K <- diag(3)
left <- aqt_refractive_camera(
  K,diag(3),center=c(-1,0,-1),
  plane_point=c(0,0,0),plane_normal=c(0,0,1),
  n_before=1,n_after=4/3,units="cm")
right <- aqt_refractive_camera(
  K,diag(3),center=c(1,0,-1),
  plane_point=c(0,0,0),plane_normal=c(0,0,1),
  n_before=1,n_after=4/3,units="cm")
xyz <- aqt_refractive_triangulate(left,right,
  matrix(c(.5,0),nrow=1),matrix(c(-.5,0),nrow=1))
stopifnot(xyz$valid[1L],xyz$z[1L]>1)
qc <- aqt_refractive_landmark_qc(left,
  matrix(c(.5,0),nrow=1),
  as.matrix(xyz[,c("x","y","z")]))
print(qc)
~~~

Mathematical examples do not constitute fish biological benchmarks.

## Research roadmap

Before a claim of *calibrated underwater reconstruction*:

1. Implement and independently verify explicit parallel AIR-GLASS-WATER
   surface transitions (with thickness, normal direction and ray validity).
2. Fit or import optical camera intrinsics and extrinsics using real
   physical calibration targets in the intended tank geometry.
3. Cross-check residuals against a trusted 3D coordinate reference
   rather than only self-consistency between two rays.
4. Propagate rig parameter, refractive index and measurement uncertainty
   coherently into XYZ, path features and tank-replicated inference.
5. Benchmark across camera angles, wall/window thickness, shadows and
   fish occlusions; distinguish ID errors from optical errors.

Relevant methodological foundations:
- Pedersen et al. (2018), CVPR Workshops, Camera Calibration for
  Underwater 3D Reconstruction Based on Ray Tracing Using Snell's Law.
- Jordt, Köser & Koch (2016), Methods in Oceanography,
  Refractive 3D reconstruction on underwater images,
  DOI:10.1016/j.mio.2016.03.001.
