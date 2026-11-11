# Exact known-XYZ reference fixture for the equal-index Snell limit.
# This validates software mathematics, not underwater camera calibration.
.aqt_known_landmark_fixture <- function(n=16L) {
  world <- cbind(
    x=seq(-.2,.8,length.out=n),
    y=.25*sin(seq_len(n)*1.3),
    z=seq(.5,1.9,length.out=n))
  cam <- function(cx) aqt_flatport_camera(
    diag(3),diag(3),c(cx,0,-1),
    c(0,0,0),c(0,0,1),glass_thickness=.1,
    n_first=1,n_glass=1,n_water=1,units="cm")
  pixel <- function(cx) cbind(
    (world[,"x"]-cx)/(world[,"z"]+1),
    world[,"y"]/(world[,"z"]+1))
  list(world=world,camera_a=cam(-1),camera_b=cam(1),
       pixel_a=pixel(-1),pixel_b=pixel(1))
}

test_that("independent physical XYZ benchmark recovers known stereo geometry", {
  f <- .aqt_known_landmark_fixture()
  b <- aqt_stereo_landmark_benchmark(
     f$camera_a,f$camera_b,f$pixel_a,f$pixel_b,
     f$world,landmark_id=paste0("landmark",seq_len(nrow(f$world))))
  expect_s3_class(b,"aqt_stereo_landmark_benchmark")
  expect_equal(b$summary$n_total,16)
  expect_equal(b$summary$n_valid,16)
  expect_equal(b$summary$valid_fraction,1)
  expect_lt(b$summary$rmse_3d,1e-8)
  expect_lt(b$summary$rmse_z,1e-8)
  expect_lt(b$summary$max_error_3d,1e-8)
  expect_false(b$calibration_certified)
  expect_equal(b$units,"cm")
  depth <- aqt_stereo_depth_audit(
     b,depth_breaks=c(0,1,1.5,2))
  expect_equal(nrow(depth),3)
  expect_equal(sum(depth$n_reference),16)
  expect_true(all(depth$valid_fraction==1))
  expect_true(all(depth$rmse_3d<1e-8))
})

test_that("invalid triangulation remains in benchmark denominator", {
  f <- .aqt_known_landmark_fixture()
  bad <- f$pixel_b
  bad[1,2] <- bad[1,2]+.7
  b <- aqt_stereo_landmark_benchmark(
      f$camera_a,f$camera_b,f$pixel_a,bad,f$world,
      max_separation=1e-7)
  expect_equal(b$summary$n_total,16)
  expect_lt(b$summary$n_valid,16)
  expect_equal(b$summary$n_invalid,16-b$summary$n_valid)
  expect_true(any(!b$per_landmark$valid))
  expect_error(aqt_stereo_depth_audit(b,c(.7,1,1.4)),
               "encompass")
  expect_error(aqt_stereo_landmark_benchmark(
    f$camera_a,f$camera_b,f$pixel_a,f$pixel_b,f$world,
    landmark_id=rep("duplicate",16)),"unique")
})

test_that("translation-only calibration improves independent heldout RMSE", {
  f <- .aqt_known_landmark_fixture()
  initial <- aqt_flatport_camera(
    diag(3),diag(3),c(-.89,.08,-.93),
    c(0,0,0),c(0,0,1),glass_thickness=.1,
    n_first=1,n_glass=1,n_water=1,units="cm")
  fit <- aqt_flatport_refine_center(
     initial,f$pixel_a,f$world,
     training=1:12,holdout=13:16,max_center_shift=.3)
  expect_equal(fit$training_n,12)
  expect_equal(fit$holdout_n,4)
  expect_equal(fit$convergence,0)
  expect_gt(fit$train_rmse_before,fit$train_rmse_after)
  expect_gt(fit$holdout_rmse_before,fit$holdout_rmse_after)
  expect_lt(fit$holdout_rmse_after,1e-4)
  expect_equal(fit$fitted_center,c(-1,0,-1),tolerance=1e-3)
  expect_identical(fit$calibration_parameters,"translation_only")
  expect_false(fit$calibration_certified)
})

test_that("calibration refuses overlapping target sets and degenerate geometry", {
  f <- .aqt_known_landmark_fixture()
  expect_error(aqt_flatport_refine_center(f$camera_a,f$pixel_a,
     f$world,training=1:12,holdout=c(12,13)),
     "disjoint")
  expect_error(aqt_flatport_refine_center(f$camera_a,f$pixel_a,
     f$world,training=1:5,holdout=6:8),
     "training")
  flat <- f$world
  flat[,3] <- 1
  expect_error(aqt_flatport_refine_center(f$camera_a,f$pixel_a,
     flat,training=1:12,holdout=13:16),
     "variation in 3D depth")
  behind <- f$world
  behind[1,3] <- -.2
  expect_error(aqt_flatport_refine_center(f$camera_a,f$pixel_a,
     behind,training=2:13,holdout=c(1,14)),
     "beyond the glass")
})


test_that("coplanar wrong matches can have tiny ray separation but large 3D error", {
  f <- .aqt_known_landmark_fixture()
  wrong <- f$pixel_b
  wrong[1,1] <- wrong[1,1]+.7
  b <- aqt_stereo_landmark_benchmark(
      f$camera_a,f$camera_b,f$pixel_a,wrong,f$world)
  expect_true(b$per_landmark$valid[1])
  expect_lt(b$per_landmark$ray_separation[1],1e-8)
  expect_gt(b$per_landmark$error_3d[1],.1)
  expect_gt(b$summary$rmse_3d,0)
  # A small ray residual is NOT proof of correct fish correspondence.
})
