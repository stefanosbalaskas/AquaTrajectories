# Wave 7E — explicit lens undistortion before underwater flat-glass geometry

## Why refraction alone is not enough

AquaTrajectories now reconstructs XYZ fish positions through an
explicit air–glass–water flat-port model using Snell's law. Its
physical camera rays require **undistorted pinhole pixel coordinates**
and externally measured camera intrinsics/extrinsics. Real video
frames may also contain significant lens distortion. Ignoring
distortion may yield apparently smooth XYZ trajectories with a
systematic spatial error, particularly far from the image centre.

This module supplies a strictly bounded perspective-lens
Brown–Conrady radial/tangential model. It is NOT an automatic
focal-length/distortion calibration tool, a universal GoPro
lens profile, or a full fisheye/omnidirectional projection.

## New public functions

- \`aqt_brown_camera()\`: declares measured intrinsic matrix \`K\`,
  radial \`k1,k2,k3\`, tangential \`p1,p2\` coefficients and an
  externally justified normalized field-of-view radius.
  \`calibration_certified=FALSE\` by design.
- \`aqt_brown_distort_pixels()\`: mathematical forward map from
  **undistorted** pinhole image positions into the corresponding
  **distorted** pixels. Out-of-field/unknown positions remain
  invalid and are never imputed.
- \`aqt_brown_undistort_pixels()\`: numerically inverts the
  forward model, checks normalized convergence and actual
  forward reprojection error. Nonconvergent, invalid or out-of-field
  results remain explicit missing values.
- \`aqt_flatport_rays_distorted()\`: applies verified inversion and
  then traces the resulting pinhole pixels through TWO refractive
  interfaces, into target water rays. It refuses mismatched
  intrinsic matrices between the lens and physical flat-port
  camera object.
- \`aqt_brown_undistort_tracks()\`: applies the same inverse model
  to canonical fish image trajectories. Preserves the original
  distorted detector pixels, camera/session/fish IDs, exact source
  timestamps, invalid/missing fish observations and per-position
  inversion errors. Refuses double correction.

## Known-geometry example

~~~r
library(aquaTrajectories)

K <- matrix(c(300,0,320, 0,290,240, 0,0,1),
            nrow=3,byrow=TRUE)
lens <- aqt_brown_camera(
  K,k1=-.08,k2=.009,k3=.0004,p1=.0008,p2=-.001,
  max_normalized_radius=1.5
)

# (a) Diagnostic demonstration: forward then inverse
undistorted <- matrix(c(320,240,460,240,365,280),
                      byrow=TRUE,ncol=2)
detector <- aqt_brown_distort_pixels(lens,undistorted)
corrected <- aqt_brown_undistort_pixels(
  lens,as.matrix(detector[,c("x_px","y_px")]))
print(corrected)

# (b) In an actual two-camera fish workflow:
# view_top_raw/view_side_raw are already verified 2D fish
# detection/tracking data, with source distorted pixels.
view_top <- aqt_brown_undistort_tracks(view_top_raw,lens_top)
view_side <- aqt_brown_undistort_tracks(view_side_raw,lens_side)
# Assumes real clock synchronization and independently reviewed
# per-observation cross-view fish correspondences.
xyz <- aqt_refractive_reconstruct_tracks(
  view_top,view_side,reviewed_matches,
  flatport_top,flatport_side,max_skew_s=.02
)
aqt_refractive_track_quality(xyz)
~~~

The example shows the API, not a real external camera calibration.

## Important limits

1. **Wide-angle/fisheye warning.** Many GoPro and action-camera
   modes are not well represented by a simple Brown perspective
   projection across their entire field of view. The original
   camera mode, lens profile, image cropping and any in-camera
   correction must be documented before this function is used.
2. K and Brown coefficients must be independently calibrated
   using appropriate images of physical targets. Nominal
   manufacturer lens settings are not themselves validated.
3. Brown undistortion and glass refraction are distinct effects.
   Lens correction cannot compensate for wrong window normal,
   thickness, media refractive indices, camera rotations,
   inter-camera synchronization or fish identity association.
4. Small roundtrip error means the inverse algorithm is
   consistent with the INPUT Brown model. It does NOT mean the
   physical lens calibration is accurate.
5. Errors in K, lens coefficients, raw fish pixel localization,
   rolling shutter, video compression and 3D correspondences
   can interact. Joint parameter uncertainty is not estimated
   by this deterministic correction.
6. A fish absent in a source frame remains unobserved. Neither
   lens correction nor refraction can reconstruct it by itself.
7. This module does not provide manufacturer-specific
   GoPro calibration, underwater fisheye fitting, independent
   physical 3D RMSE or confidence-region certification.

## Independent science gates

- Compare independently surveyed calibration targets across
  the actual image field, especially corners and depth changes.
- Establish physical lens model validity for the precise
  GoPro/underwater housing combination and video mode.
- Evaluate source tracking uncertainty across video occlusions,
  shadows, strong reflections, water turbidity and fish crossings.
- Compare actual XYZ reconstruction error to independent
  underwater metrology, not solely lens roundtrip or stereo-ray
  consistency residuals.
