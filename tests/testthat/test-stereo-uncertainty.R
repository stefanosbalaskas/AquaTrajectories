test_that("zero pixel jitter returns exact deterministic XYZ without RNG side effects", {
  P1 <- cbind(diag(3),c(0,0,0))
  P2 <- cbind(diag(3),c(-1,0,0))
  a <- matrix(c(.5,.25),nrow=1)
  b <- matrix(c(.25,.25),nrow=1)
  set.seed(2026)
  rng <- .Random.seed
  out <- aqt_stereo_pixel_mc(a,b,P1,P2,sigma_px=0,draws=40,seed=12)
  expect_identical(.Random.seed,rng)
  expect_equal(unlist(out[1,c("x","y","z")],use.names=FALSE),
               c(2,1,4),tolerance=1e-9)
  expect_equal(unlist(out[1,c("sd_x","sd_y","sd_z")],use.names=FALSE),
               rep(0,3),tolerance=1e-9)
  expect_equal(out$valid_fraction,1)
  expect_equal(out$lower_z,4,tolerance=1e-9)
  expect_equal(out$upper_z,4,tolerance=1e-9)
})

test_that("pixel localization noise creates reproducible conditional intervals", {
  P1 <- cbind(diag(3),c(0,0,0))
  P2 <- cbind(diag(3),c(-1,0,0))
  a <- matrix(c(.5,.25),nrow=1)
  b <- matrix(c(.25,.25),nrow=1)
  out <- aqt_stereo_pixel_mc(a,b,P1,P2,sigma_px=.005,
                             draws=200,seed=27,level=.95)
  out2 <- aqt_stereo_pixel_mc(a,b,P1,P2,sigma_px=.005,
                              draws=200,seed=27,level=.95)
  expect_equal(out,out2)
  expect_true(all(out[1,c("sd_x","sd_y","sd_z")] > 0))
  expect_true(all(out[1,c("upper_x","upper_y","upper_z")] >
                  out[1,c("lower_x","lower_y","lower_z")]))
  expect_gte(out$valid_fraction,.95)
  expect_equal(attr(out,"aqt_conditional_model")$sigma_px,c(.005,.005))
  expect_error(aqt_stereo_pixel_mc(a,b,P1,P2,sigma_px=-1),"sigma_px")
  expect_error(aqt_stereo_pixel_mc(a,b,P1,P2,draws=10),"draws")
})

test_that("uncertainty wrapper maps source camera IDs and preserves 3D scope", {
  P1 <- cbind(diag(3),c(0,0,0))
  P2 <- cbind(diag(3),c(-1,0,0))
  rig <- aqt_rig_new(list(TOP=P1,SIDE=P2),optical_path="air_only")
  top <- aqt_tracks(data.frame(session_id="S1",camera_id="TOP",
    track_id="topA",time_s=c(0,1),x=c(.5,.75),y=.25))
  side <- aqt_tracks(data.frame(session_id="S1",camera_id="SIDE",
    track_id="sideB",time_s=c(0,1),x=c(.25,.5),y=.25))
  match <- data.frame(session_id="S1",id_a="topA",id_b="sideB",
     time_a_s=c(0,1),time_b_s=c(0,1),fish_id="F1")
  xyz <- aqt_reconstruct_3d(top,side,match,rig)
  uw <- aqt_reconstruction_pixel_uncertainty(
    xyz,top,side,sigma_px=.005,draws=70,seed=35)
  expect_s3_class(uw,"aqt_tracks")
  expect_true(aqt_tracks_validate(uw))
  expect_equal(nrow(uw),2)
  expect_true(all(uw$sd_x>0))
  expect_equal(uw$x,xyz$x)
  expect_true(all(uw$valid_fraction>=.95))
  expect_identical(attr(uw,"aqt_conditional_model")$draws,70)
})
