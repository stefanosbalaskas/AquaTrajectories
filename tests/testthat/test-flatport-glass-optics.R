test_that("parallel glass port reduces to exact pinhole at equal optical indices", {
  left <- aqt_flatport_camera(diag(3),diag(3),c(-1,0,-1),
    c(0,0,0),c(0,0,1),glass_thickness=.1,
    n_first=1,n_glass=1,n_water=1,units="cm")
  right <- aqt_flatport_camera(diag(3),diag(3),c(1,0,-1),
    c(0,0,0),c(0,0,1),glass_thickness=.1,
    n_first=1,n_glass=1,n_water=1,units="cm")
  p1 <- matrix(c(.5,0),nrow=1)
  p2 <- matrix(c(-.5,0),nrow=1)
  ray <- aqt_flatport_rays(left,p1)
  expect_true(ray$valid[1])
  expect_equal(ray$origin_z[1],.1,tolerance=1e-12)
  x <- aqt_refractive_triangulate(left,right,p1,p2)
  expect_true(x$valid[1])
  expect_equal(unlist(x[1,c("x","y","z")],use.names=FALSE),
               c(0,0,1),tolerance=1e-9)
  expect_lt(x$separation[1],1e-9)
})

test_that("Snell refraction follows both air-glass-water surfaces", {
  make <- function(x) aqt_flatport_camera(diag(3),diag(3),
     c(x,0,-1),c(0,0,0),c(0,0,1),
     glass_thickness=.1,n_first=1,n_glass=1.5,
     n_water=4/3,units="cm")
  a <- make(-1);b <- make(1)
  left <- matrix(c(.5,0),nrow=1)
  right <- matrix(c(-.5,0),nrow=1)
  water_ray <- aqt_flatport_rays(a,left)
  expect_true(water_ray$valid[1])
  expect_equal(water_ray$origin_z[1],.1,tolerance=1e-10)
  expect_gt(water_ray$origin_x[1],-.5)
  expect_lt(water_ray$origin_x[1],-.45)
  p <- aqt_refractive_triangulate(a,b,left,right)
  expect_true(p$valid[1])
  expect_equal(p$x[1],0,tolerance=1e-9)
  expect_gt(p$z[1],1)
  expect_lt(p$z[1],1.6)
  expect_lt(p$separation[1],1e-9)
  qc <- aqt_refractive_landmark_qc(a,left,
      as.matrix(p[,c("x","y","z")]))
  expect_lt(qc$rmse,1e-9)
  expect_false(qc$calibration_certified)
})

test_that("flatport rejects invalid measured glass and optical geometry", {
  fun <- function(thickness=.1,nw=1.333)
    aqt_flatport_camera(diag(3),diag(3),c(0,0,-1),
      c(0,0,0),c(0,0,1),glass_thickness=thickness,
      n_first=1,n_glass=1.5,n_water=nw)
  expect_error(fun(thickness=0),"glass_thickness")
  expect_error(fun(thickness=-.1),"glass_thickness")
  expect_error(fun(nw=-1),"n_water")
  expect_error(aqt_flatport_rays(list(),matrix(0,nrow=1,ncol=2)),
               "Expected")
  camera <- fun()
  expect_error(aqt_flatport_rays(camera,matrix(NA_real_,1,2)),
               "pixels")
})
