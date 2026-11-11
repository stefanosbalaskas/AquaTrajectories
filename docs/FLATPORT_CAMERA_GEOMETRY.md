# Wave 6D: Parallel flat-glass underwater camera rays

## Optical geometry

AquaTrajectories now supports a second, physically explicit, ideal
THREE-MEDIUM optical model through TWO PARALLEL PLANAR interfaces:
camera-side medium (typically air) -> flat glass slab -> target medium
(typically water).

- aqt_flatport_camera(): defines externally supplied intrinsics K,
  world rotation, world optical centre, point and normal of the
  camera-side window surface, glass slab thickness, optical indices
  for all three media, and physical unit system.
- aqt_flatport_rays(): traces undistorted camera pixel rays to the
  near glass surface, applies Snell's law, intersects the far glass
  surface at known NORMAL separation, then applies Snell again.
  Invalid intersections and total internal reflection are flagged.
- aqt_refractive_triangulate() and aqt_refractive_landmark_qc()
  now automatically accept flatport cameras, reusing the validated
  geometric routines for positive-ray stereo midpoint solutions and
  independent landmark residual checks.

## Known geometry

Set all indices to 1; any glass thickness should give exactly the
same 3D intersection as an undistorted pinhole model.

With n_first=1, n_glass=1.5 and n_water=4/3, a ray crossing the slab
bends at both interfaces. When the glass surfaces are planar and
parallel, horizontal ray direction changes through refraction but
retains an offset introduced inside glass. Thus it is not equivalent
to a single imaginary air/water interface.

## Illustrative idealized example

~~~r
library(aquaTrajectories)
K <- diag(3)
left <- aqt_flatport_camera(
  K,diag(3),center=c(-1,0,-1),
  glass_front_point=c(0,0,0),glass_normal=c(0,0,1),
  glass_thickness=.1,n_first=1,n_glass=1.5,n_water=4/3,
  units="cm"
)
right <- aqt_flatport_camera(
  K,diag(3),center=c(1,0,-1),
  glass_front_point=c(0,0,0),glass_normal=c(0,0,1),
  glass_thickness=.1,n_first=1,n_glass=1.5,n_water=4/3,
  units="cm"
)
x <- aqt_refractive_triangulate(left,right,
  matrix(c(.5,0),nrow=1),matrix(c(-.5,0),nrow=1))
stopifnot(x$valid[1],x$separation[1]<1e-8)
aqt_refractive_landmark_qc(left,
  matrix(c(.5,0),nrow=1),
  as.matrix(x[,c("x","y","z")]))
~~~

## Research and measurement limitations

These mathematical functions do NOT perform actual camera calibration
or estimate glass surface normals, slab thickness, optical indices,
fisheye distortion, rolling shutter, camera clock drift or biological
cross-view fish matching. The user must obtain these values from a
trusted calibration process.

The model assumes two strictly parallel, physically planar surfaces,
homogeneous media, undistorted source pixels and fixed optics. Nonparallel
glass walls, dome ports, warped aquarium windows, free-surface ripples,
unknown lens distortion and cameras on the water side require other
models. Even a small ray separation or landmark residual is not proof
that all optical parameters are accurate. When actual 3D fish
metrology matters, validate against independent physical landmarks
through the *same* tank wall and camera arrangement, across depths
and image corners.

Differences between projected position sensitivity and true physical
3D position uncertainty remain unqualified. This optics module does
not by itself produce statistically calibrated confidence regions.

## Further work

- Import and estimate multi-camera intrinsics/extrinsics from real
  calibration patterns.
- Optimize refractive surface planes and glass thickness against
  independent physical targets with uncertainty estimates.
- Model coherent calibration and clock drift across the recording.
- Jointly propagate optics and alternative fish IDs through fish
  movement metrics and tank-level treatment inference.
- Validate absolute 3D RMSE and coverage against independent physical
  ground truth.

Scientific references:
- Jordt, Köser & Koch (2016), Methods in Oceanography,
  DOI 10.1016/j.mio.2016.03.001.
- Pedersen et al. (2018), CVPR Workshops, Camera Calibration for
  Underwater 3D Reconstruction Based on Ray Tracing Using Snell's Law.
