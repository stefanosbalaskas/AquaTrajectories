# PRIORITY A: exact-answer optical and conditional uncertainty references.
# This uses ideal pinhole geometry and synthetic noise scenarios only.
# It never certifies underwater real-camera calibration or biological identity.

test_that("pinhole stereo matches independent ideal disparity geometry", {
  P1 <- rbind(c(1,0,0,0),c(0,1,0,0),c(0,0,1,0))
  P2 <- rbind(c(1,0,0,-2),c(0,1,0,0),c(0,0,1,0))
  xyz <- rbind(c(3,4,10),c(-2,1,5),c(1,2,20))
  # Derive stereo image coordinates directly by analytical disparity.
  left <- cbind(xyz[,1]/xyz[,3],xyz[,2]/xyz[,3])
  right <- cbind((xyz[,1]-2)/xyz[,3],xyz[,2]/xyz[,3])
  rig <- aqt_rig_new(list(TOP=P1,SIDE=P2),
                      units="cm",optical_path="air_only")
  expect_true(aqt_rig_validate(rig))
  expect_equal(aqt_rig_baseline(rig,"TOP","SIDE"),2,tolerance=1e-12)
  expect_equal(as.matrix(aqt_rig_project(rig,xyz,"TOP")[,c("x","y")]),
               left,tolerance=1e-12,ignore_attr=TRUE)
  expect_equal(as.matrix(aqt_rig_project(rig,xyz,"SIDE")[,c("x","y")]),
               right,tolerance=1e-12,ignore_attr=TRUE)
  reconstructed <- aqt_triangulate_pairs(left,right,P1,P2)
  expect_true(all(reconstructed$valid))
  expect_equal(as.matrix(reconstructed[,c("x","y","z")]),xyz,
               tolerance=1e-9,ignore_attr=TRUE)
  expect_lt(max(reconstructed$reprojection_rmse),1e-9)
  expected_z <- 2/(left[,1]-right[,1])
  expect_equal(reconstructed$z,expected_z,tolerance=1e-9)
  expect_error(aqt_rig_project(aqt_rig_new(
    list(TOP=P1,SIDE=P2),optical_path="refractive_interface"),
    xyz,"TOP"),"air_only")
})

test_that("Brown forward lens model matches explicit analytic radial formula", {
  K <- matrix(c(900,0,320,0,920,240,0,0,1),3,3,byrow=TRUE)
  model <- aqt_brown_camera(K,k1=.08,k2=-.02,p1=.005,p2=-.003)
  xy <- rbind(c(.1,.2),c(-.3,.1))
  px <- cbind(900*xy[,1]+320,920*xy[,2]+240)
  transformed <- aqt_brown_distort_pixels(model,px)
  r2 <- rowSums(xy^2)
  radial <- 1+.08*r2-.02*r2^2
  dx <- 2*.005*xy[,1]*xy[,2]-.003*(r2+2*xy[,1]^2)
  dy <- .005*(r2+2*xy[,2]^2)-2*.003*xy[,1]*xy[,2]
  expected <- cbind(900*(xy[,1]*radial+dx)+320,
                    920*(xy[,2]*radial+dy)+240)
  expect_equal(unname(as.matrix(transformed[,c("x_px","y_px")])),
               unname(expected),tolerance=1e-10)
  expect_true(all(transformed$valid))
  inverse <- aqt_brown_undistort_pixels(model,
    as.matrix(transformed[,c("x_px","y_px")]),max_roundtrip_px=1e-5)
  expect_true(all(inverse$valid))
  expect_equal(unname(as.matrix(inverse[,c("x_px","y_px")])),
               unname(px),tolerance=1e-6)
  expect_true(all(inverse$roundtrip_error_px<=1e-5))
  absent <- aqt_brown_distort_pixels(model,
    rbind(c(NA_real_,NA_real_),px[1,]))
  expect_false(absent$valid[1])
})

test_that("zero assumed pixel noise returns exactly deterministic stereo XYZ", {
  P1 <- rbind(c(1,0,0,0),c(0,1,0,0),c(0,0,1,0))
  P2 <- rbind(c(1,0,0,-2),c(0,1,0,0),c(0,0,1,0))
  truth <- matrix(c(3,4,10),nrow=1L)
  a <- matrix(c(.3,.4),nrow=1L)
  b <- matrix(c(.1,.4),nrow=1L)
  set.seed(108); before <- .Random.seed
  result <- aqt_stereo_pixel_mc(a,b,P1,P2,sigma_px=0,
                                draws=30L,seed=42L)
  expect_identical(.Random.seed,before)
  expect_equal(unname(as.numeric(unlist(result[1,c("x","y","z"),drop=FALSE],use.names=FALSE))),
               unname(as.numeric(truth)),tolerance=1e-10)
  expect_equal(unname(as.numeric(unlist(result[1,c("sd_x","sd_y","sd_z"),drop=FALSE],use.names=FALSE))),
               rep(0,3),tolerance=1e-10)
  expect_equal(unname(as.numeric(unlist(result[1,c("lower_x","lower_y","lower_z"),drop=FALSE],use.names=FALSE))),
               unname(as.numeric(truth)),tolerance=1e-10)
  expect_equal(unname(as.numeric(unlist(result[1,c("upper_x","upper_y","upper_z"),drop=FALSE],use.names=FALSE))),
               unname(as.numeric(truth)),tolerance=1e-10)
  expect_equal(result$n_valid_draws,30L)
  expect_equal(result$valid_fraction,1)
  model <- attr(result,"aqt_conditional_model")
  expect_true("refraction" %in% model$excludes)
  expect_true("identity ambiguity" %in% model$excludes)
})

test_that("zero-noise fish scenario preserves source trajectories and units", {
  d <- data.frame(session_id="S",camera_id="WORLD",
    track_id="0007",time_s=c(0,.1,.2,.3),
    x=c(0,1,2,3),y=c(0,0,1,1),
    observed=c(TRUE,TRUE,FALSE,TRUE))
  original <- aqt_tracks(d,units="cm",coordinate_system="tank")
  set.seed(777); before <- .Random.seed
  ens <- aqt_trajectory_ensemble(original,sigma=0,systematic_sd=0,
                                  rho=0,draws=20L,seed=8L,max_gap_s=.15)
  expect_identical(.Random.seed,before)
  expect_true(ens$assumptions$conditional_on_fixed_identity)
  draw <- aqt_ensemble_tracks(ens,draw=3L)
  expect_identical(attr(draw,"aqt_units"),"cm")
  expect_identical(draw$observed,original$observed)
  expect_equal(draw$x[draw$observed],original$x[original$observed])
  expect_equal(draw$y[draw$observed],original$y[original$observed])
  expect_true(is.na(draw$x[3]))
  expected <- aqt_path_summary(original,max_gap_s=.15)
  actual <- aqt_path_summary(draw,max_gap_s=.15)
  expect_equal(actual$path_length,expected$path_length,tolerance=1e-12)
  expect_equal(actual$valid_duration_s,expected$valid_duration_s,
               tolerance=1e-12)
})

test_that("zone occupancy agrees with independent manually counted frames", {
  d <- data.frame(session_id="S",camera_id="TOP",track_id="0008",
   time_s=0:4,x=c(.2,.8,1.2,1.8,999),
   y=c(.2,.8,1.2,.8,999),observed=c(TRUE,TRUE,TRUE,TRUE,FALSE))
  tracks <- aqt_tracks(d,units="cm",coordinate_system="tank")
  z <- data.frame(zone_id=c("left","right"),
    xmin=c(0,1),xmax=c(1,2),ymin=c(0,0),ymax=c(2,2))
  got <- aqt_zone_occupancy(tracks,z)
  expect_equal(got$n_valid,c(4L,4L))
  expect_equal(got$n_in_zone,c(2L,2L))
  expect_equal(got$sample_fraction,c(.5,.5))
  expect_error(aqt_zone_occupancy(tracks,
     transform(z,zmin=0,zmax=2)),"Depth bounds")
})
