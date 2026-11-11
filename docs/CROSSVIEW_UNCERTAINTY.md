# Wave 3B: geometry-aided multiview correspondence and conditional XYZ uncertainty

## Implemented functions

- aqt_view_candidates(): enumerates temporally compatible two-camera
  observation hypotheses within an explicit computational cap, with
  camera-local IDs, triangulated XYZ, reprojection RMSE and time skew.
- aqt_candidate_rank(): ranks geometrical hypotheses, reports plausible
  alternatives, and explicitly avoids asserting a fish identity.
- aqt_correspondences_from_review(): requires human-confirmed candidate IDs,
  fish identities, reviewer and reason; enforces one-to-one observed-frame
  correspondence.
- aqt_stereo_pixel_mc(): estimates conditional XYZ variability from an
  assumed independent Gaussian image-localization error via Monte Carlo,
  with sample standard deviations, covariance terms and empirical intervals.
- aqt_reconstruction_pixel_uncertainty(): attaches these pixel-jitter
  uncertainty summaries to original reconstructed 3D fish tracks.

## Runnable known-truth example (non-aquatic pinhole calibration)

~~~r
library(aquaTrajectories)

P1 <- cbind(diag(3),c(0,0,0))
P2 <- cbind(diag(3),c(-1,0,0))
rig <- aqt_rig_new(list(TOP=P1,SIDE=P2),
                   units="cm",optical_path="air_only")

top <- aqt_tracks(data.frame(session_id="S1",camera_id="TOP",
  track_id=c("topA","topB"),time_s=0,x=c(.5,.75),y=.25))
side <- aqt_tracks(data.frame(session_id="S1",camera_id="SIDE",
  track_id=c("sideC","sideD"),time_s=0,x=c(.25,.5),y=.25))

hypotheses <- aqt_view_candidates(top,side,rig,max_skew_s=0)
print(aqt_candidate_rank(hypotheses,max_reprojection_px=1))

# Verified externally for this synthetic geometry, not chosen by software:
chosen <- which(
  (hypotheses$id_a=="topA" & hypotheses$id_b=="sideC") |
  (hypotheses$id_a=="topB" & hypotheses$id_b=="sideD")
)
review <- data.frame(candidate_id=hypotheses$candidate_id[chosen],
  fish_id=c("fishA","fishB"),reviewer="simulation truth",
  reason="known calibration fixture")
matched <- aqt_correspondences_from_review(hypotheses,review)
xyz <- aqt_reconstruct_3d(top,side,matched,rig,max_skew_s=0)
print(xyz[,c("track_id","x","y","z","reprojection_rmse_px")])

conditional <- aqt_reconstruction_pixel_uncertainty(
  xyz,top,side,sigma_px=.005,draws=100,seed=7
)
print(conditional[,c("track_id","z","sd_z","lower_z","upper_z")])
~~~

## Scientific limitations

1. A good triangulation fit does not prove correct biological identity;
   candidate scores can be tied or ambiguous.
2. A human reviewer records accepted correspondence hypotheses. The
   package cannot independently verify biological identity from geometry.
3. Only an explicitly declared non-refractive air-only camera model is
   supported. The default unknown and a refractive optical path are blocked.
   Through-glass and underwater fish recordings are not automatically valid.
4. Image pixel-jitter intervals are conditional mathematical sensitivity
   summaries, not calibrated frequentist or Bayesian intervals for true XYZ.
5. The current error model assumes independent Gaussian localization errors.
   It does not represent camera-calibration, clock, refraction, correlated
   trajectories, missing tracks, or identity-switch uncertainty.
6. No automatic species recognition, fish detection, full 3D anatomical
   mesh, or biologically validated stress classification is provided.
7. Large recordings should be processed in manageable temporal subsets:
   candidate enumeration is intentionally capped.

## Next research work

External camera calibration inputs; known-landmark reprojection validation;
aquatic refraction-aware camera rays; correlated camera/timing uncertainty;
alternative identity-ensemble scenarios; movement uncertainty propagation;
real aquatic reference annotations and scientifically calibrated coverage.
