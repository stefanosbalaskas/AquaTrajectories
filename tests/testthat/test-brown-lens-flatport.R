.aqt_brown_fixture <- function() {
  K <- matrix(c(300,0,320,
                0,290,240,
                0,0,1),3,3,byrow=TRUE)
  lens <- aqt_brown_camera(K,k1=-.08,k2=.009,
    p1=.0008,p2=-.001,k3=.0004,max_normalized_radius=2)
  cam <- function(cx) aqt_flatport_camera(
    K,diag(3),center=c(cx,0,-1),
    glass_front_point=c(0,0,0),glass_normal=c(0,0,1),
    glass_thickness=.1,n_first=1,n_glass=1,n_water=1,
    units="cm")
  list(K=K,lens=lens,left=cam(-1),right=cam(1))
}

test_that("Brown forward/inverse recovers independently supplied source pixels", {
  f <- .aqt_brown_fixture()
  p <- matrix(c(320,240,470,240,165,290,
                360,185,280,310,510,355),ncol=2,byrow=TRUE)
  distorted <- aqt_brown_distort_pixels(f$lens,p)
  expect_true(all(distorted$valid))
  corrected <- aqt_brown_undistort_pixels(
    f$lens,as.matrix(distorted[,c("x_px","y_px")]))
  expect_true(all(corrected$valid))
  expect_lt(max(abs(corrected$x_px-p[,1])),1e-6)
  expect_lt(max(abs(corrected$y_px-p[,2])),1e-6)
  expect_true(all(corrected$roundtrip_error_px<1e-6))
  expect_false(f$lens$calibration_certified)
})

test_that("zero-distortion pinhole limit is exact on finite source pixels", {
  f <- .aqt_brown_fixture()
  zero <- aqt_brown_camera(f$K)
  p <- matrix(c(320,240,365,200,480,275),ncol=2,byrow=TRUE)
  d <- aqt_brown_distort_pixels(zero,p)
  expect_equal(d$x_px,p[,1],tolerance=1e-9)
  expect_equal(d$y_px,p[,2],tolerance=1e-9)
  u <- aqt_brown_undistort_pixels(zero,p)
  expect_true(all(u$valid))
  expect_equal(u$x_px,p[,1],tolerance=1e-9)
  expect_equal(u$y_px,p[,2],tolerance=1e-9)
})

test_that("undistorted air-glass-water rays agree with raw corrected lens rays", {
  f <- .aqt_brown_fixture()
  und <- matrix(c(420,245,470,280,355,260),ncol=2,byrow=TRUE)
  distorted <- aqt_brown_distort_pixels(f$lens,und)
  ray_raw <- aqt_flatport_rays_distorted(
    f$left,f$lens,as.matrix(distorted[,c("x_px","y_px")]))
  ray_und <- aqt_flatport_rays(f$left,und)
  expect_true(all(ray_raw$valid))
  expect_true(all(ray_raw$lens_undistortion_valid))
  expect_equal(as.matrix(ray_raw[,1:6]),
               as.matrix(ray_und[,1:6]),tolerance=1e-7)
  expect_true(all(ray_raw$lens_roundtrip_error_px<1e-6))
  expect_false(attr(ray_raw,"aqt_lens_calibration_certified"))
  bad <- f$right
  bad$K[1,1] <- bad$K[1,1]+1
  expect_error(aqt_flatport_rays_distorted(
      bad,f$lens,as.matrix(distorted[,c("x_px","y_px")])),
      "identical intrinsics")
})

test_that("audited lens corrected video tracks reconstruct exact known XYZ", {
  f <- .aqt_brown_fixture()
  truth_x <- 0:4/10
  pixel <- function(cx) cbind(
    320+f$K[1,1]*(truth_x-cx)/2,
    rep(240,length(truth_x)))
  raw <- function(px,cam,id) {
    d <- aqt_brown_distort_pixels(f$lens,px)
    aqt_tracks(data.frame(session_id="S",camera_id=cam,
      track_id=id,time_s=0:4,
      x=d$x_px,y=d$y_px))
  }
  view_a <- raw(pixel(-1),"TOP","A")
  view_b <- raw(pixel(1),"SIDE","B")
  corrected_a <- aqt_brown_undistort_tracks(view_a,f$lens)
  corrected_b <- aqt_brown_undistort_tracks(view_b,f$lens)
  expect_true(all(corrected_a$lens_undistortion_valid))
  expect_true(all(corrected_b$lens_undistortion_valid))
  expect_equal(corrected_a$x,pixel(-1)[,1],tolerance=1e-7)
  expect_true(all(corrected_a$distorted_x_px !=
                   corrected_a$x))
  pairs <- data.frame(session_id="S",id_a="A",id_b="B",
    time_a_s=0:4,time_b_s=0:4,fish_id="F")
  xyz <- aqt_refractive_reconstruct_tracks(
    corrected_a,corrected_b,pairs,f$left,f$right)
  expect_equal(xyz$x,truth_x,tolerance=1e-7)
  expect_equal(xyz$y,rep(0,5),tolerance=1e-7)
  expect_equal(xyz$z,rep(1,5),tolerance=1e-7)
  expect_true(all(xyz$observed))
  expect_false(attr(corrected_a,"aqt_lens_calibration_certified"))
  expect_error(aqt_brown_undistort_tracks(corrected_a,f$lens),
    "double correction")
})

test_that("unknown and out-of-domain fish pixels remain invalid", {
  f <- .aqt_brown_fixture()
  limited <- aqt_brown_camera(f$K,max_normalized_radius=.1)
  source <- matrix(c(320,240,510,240,NA,NA),
                   ncol=2,byrow=TRUE)
  u <- aqt_brown_undistort_pixels(limited,source)
  expect_identical(u$valid,c(TRUE,FALSE,FALSE))
  expect_true(all(is.na(u$x_px[2:3])))
  d <- aqt_brown_distort_pixels(limited,source)
  expect_identical(d$valid,c(TRUE,FALSE,FALSE))
  tracks <- aqt_tracks(data.frame(session_id="S",camera_id="TOP",
    track_id="A",time_s=0:2,x=source[,1],y=source[,2]))
  corrected <- aqt_brown_undistort_tracks(tracks,limited)
  expect_identical(corrected$observed,c(TRUE,FALSE,FALSE))
  expect_true(all(is.na(corrected$x[2:3])))
  expect_true(all(is.na(corrected$y[2:3])))
})

test_that("unsupported/invalid camera intrinsics and parameters are rejected", {
  f <- .aqt_brown_fixture()
  K <- f$K
  K[1,1] <- -100
  expect_error(aqt_brown_camera(K),"positive-focal")
  expect_error(aqt_brown_camera(f$K,k1=Inf),"coefficients")
  expect_error(aqt_brown_camera(f$K,
     max_normalized_radius=0),"normalized radius")
  expect_error(aqt_brown_undistort_pixels(
    f$lens,matrix(0,nrow=1,ncol=2),
    max_iter=0),"max_iter")
  expect_error(aqt_brown_distort_pixels(
    f$lens,matrix(Inf,1,2)),"without infinities")
})


test_that("unknown fish image detections remain invalid through glass ray tracing", {
  f <- .aqt_brown_fixture()
  p <- matrix(c(320,240,NA_real_,NA_real_),ncol=2,byrow=TRUE)
  ray <- aqt_flatport_rays_distorted(f$left,f$lens,p)
  expect_true(ray$valid[1])
  expect_false(ray$valid[2])
  expect_equal(ray$lens_undistortion_valid,c(TRUE,FALSE))
  expect_true(is.na(ray$origin_x[2]))
  expect_true(is.na(ray$undistorted_x_px[2]))
  expect_false(attr(ray,"aqt_lens_calibration_certified"))
})
