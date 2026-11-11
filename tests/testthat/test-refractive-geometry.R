test_that("single-interface rays reduce exactly to pinhole rays at equal indices", {
  K <- diag(3); R <- diag(3)
  one <- aqt_refractive_camera(K,R,c(-1,0,-1),c(0,0,0),c(0,0,1),
                              n_before=1,n_after=1,units="cm")
  two <- aqt_refractive_camera(K,R,c(1,0,-1),c(0,0,0),c(0,0,1),
                              n_before=1,n_after=1,units="cm")
  out <- aqt_refractive_triangulate(one,two,
      matrix(c(.5,0),nrow=1),matrix(c(-.5,0),nrow=1))
  expect_true(out$valid[1])
  expect_equal(unname(unlist(out[1,c("x","y","z")])),
               c(0,0,1),tolerance=1e-9)
  expect_lt(out$separation[1],1e-9)
  rays <- aqt_refractive_rays(one,matrix(c(.5,0),nrow=1))
  expect_true(rays$valid[1])
  expect_equal(rays$origin_z[1],0,tolerance=1e-12)
})

test_that("Snell bending gives a more distant underwater crossing than pinhole", {
  c1 <- aqt_refractive_camera(diag(3),diag(3),c(-1,0,-1),
    c(0,0,0),c(0,0,1),n_before=1,n_after=4/3,units="cm")
  c2 <- aqt_refractive_camera(diag(3),diag(3),c(1,0,-1),
    c(0,0,0),c(0,0,1),n_before=1,n_after=4/3,units="cm")
  pix1 <- matrix(c(.5,0),nrow=1)
  pix2 <- matrix(c(-.5,0),nrow=1)
  xyz <- aqt_refractive_triangulate(c1,c2,pix1,pix2)
  expect_true(xyz$valid[1])
  expect_equal(xyz$x[1],0,tolerance=1e-9)
  expect_equal(xyz$y[1],0,tolerance=1e-9)
  expect_gt(xyz$z[1],1.2)
  expect_lt(xyz$z[1],1.6)
  expect_lt(xyz$separation[1],1e-9)
  truth <- matrix(as.numeric(xyz[1,c("x","y","z")]),nrow=1)
  qc <- aqt_refractive_landmark_qc(c1,pix1,truth)
  expect_equal(qc$n_valid,1)
  expect_lt(qc$rmse,1e-9)
  expect_false(qc$calibration_certified)
})

test_that("invalid geometry is rejected rather than inventing 3D accuracy", {
  K <- diag(3);R <- diag(3)
  expect_error(aqt_refractive_camera(K,matrix(1,3,3),
      c(0,0,-1),c(0,0,0),c(0,0,1)),"rotation")
  expect_error(aqt_refractive_camera(K,R,
      c(0,0,1),c(0,0,0),c(0,0,1)),"in front")
  expect_error(aqt_refractive_camera(K,R,
      c(0,0,-1),c(0,0,0),c(0,0,1),n_after=-1),
      "Refractive indices")
  c1 <- aqt_refractive_camera(K,R,c(-1,0,-1),
    c(0,0,0),c(0,0,1))
  c2 <- aqt_refractive_camera(K,R,c(1,0,-1),
    c(0,0,0),c(0,0,1))
  expect_error(aqt_refractive_triangulate(c1,c2,
    matrix(c(.5,0),nrow=1),matrix(0,nrow=2,ncol=2)),"same number")
  expect_error(aqt_refractive_rays(c1,matrix(c(Inf,0),nrow=1)),
               "pixels")
})


test_that("total internal reflection yields explicitly invalid rays", {
  camera <- aqt_refractive_camera(diag(3),diag(3),
    c(0,0,-1),c(0,0,0),c(0,0,1),
    n_before=1.5,n_after=1)
  rays <- aqt_refractive_rays(camera,matrix(c(4,0),nrow=1))
  expect_false(rays$valid[1])
  expect_true(all(is.na(unlist(rays[1,1:6]))))
})
