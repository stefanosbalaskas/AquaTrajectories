test_that("calibrated pinhole rig recovers known camera baseline and projections", {
  P1 <- cbind(diag(3),c(0,0,0))
  P2 <- cbind(diag(3),c(-1,0,0))
  rig <- aqt_rig_new(list(TOP=P1,SIDE=P2),units="cm",optical_path="air_only")
  expect_true(aqt_rig_validate(rig))
  expect_equal(aqt_rig_baseline(rig,"TOP","SIDE"),1)
  pts <- matrix(c(2,1,4,3,1,4),byrow=TRUE,ncol=3)
  a <- aqt_rig_project(rig,pts,"TOP")
  b <- aqt_rig_project(rig,pts,"SIDE")
  expect_equal(a$x,c(.5,.75))
  expect_equal(b$x,c(.25,.5))
  expect_equal(a$y,c(.25,.25))
  expect_error(aqt_rig_new(list(TOP=P1)),"two or more")
  expect_error(aqt_rig_new(list(TOP=P1,SIDE=cbind(matrix(0,3,3),1))),
               "invertible")
})

test_that("externally matched two-camera tracks recover world XYZ", {
  P1 <- cbind(diag(3),c(0,0,0))
  P2 <- cbind(diag(3),c(-1,0,0))
  rig <- aqt_rig_new(list(TOP=P1,SIDE=P2),units="cm",optical_path="air_only")
  top <- aqt_tracks(data.frame(session_id="S1",camera_id="TOP",
     track_id="top_9",time_s=c(0,1),x=c(.5,.75),y=c(.25,.25)))
  side <- aqt_tracks(data.frame(session_id="S1",camera_id="SIDE",
     track_id="side_3",time_s=c(.001,1.001),x=c(.25,.5),y=c(.25,.25)))
  pair <- data.frame(session_id="S1",id_a="top_9",id_b="side_3",
    time_a_s=c(0,1),time_b_s=c(.001,1.001),fish_id="fishA")
  xyz <- aqt_reconstruct_3d(top,side,pair,rig,max_skew_s=.01)
  expect_s3_class(xyz,"aqt_tracks")
  expect_identical(attr(xyz,"aqt_dimension"),3L)
  expect_equal(xyz$x,c(2,3),tolerance=1e-9)
  expect_equal(xyz$y,c(1,1),tolerance=1e-9)
  expect_equal(xyz$z,c(4,4),tolerance=1e-9)
  expect_true(all(xyz$reprojection_rmse_px<1e-9))
  q <- aqt_reconstruction_quality(xyz)
  expect_equal(q$n_reconstructed,2)
  expect_equal(q$missing_fraction,0)
  expect_equal(q$max_time_skew_s,.001,tolerance=1e-9)
  expect_error(aqt_reconstruct_3d(top,side,transform(pair,time_b_s=5),
               rig,max_skew_s=.01),"skew")
  expect_error(aqt_reconstruct_3d(top,side,rbind(pair,pair[1,,drop=FALSE]),rig),
               "multiple fish")
})

test_that("raw underwater interfaces cannot be treated as pinhole calibration", {
  P1 <- cbind(diag(3),c(0,0,0))
  P2 <- cbind(diag(3),c(-1,0,0))
  rig <- aqt_rig_new(list(TOP=P1,SIDE=P2),
                     optical_path="refractive_interface")
  top <- aqt_tracks(data.frame(session_id="S",camera_id="TOP",
    track_id="a",time_s=0,x=.5,y=.25))
  side <- aqt_tracks(data.frame(session_id="S",camera_id="SIDE",
    track_id="b",time_s=0,x=.25,y=.25))
  pair <- data.frame(session_id="S",id_a="a",id_b="b",
    time_a_s=0,time_b_s=0,fish_id="F")
  expect_error(aqt_reconstruct_3d(top,side,pair,rig),"Refraction")
})


test_that("correspondence lookup uses stable per-timestamp serialization", {
  P1 <- cbind(diag(3),c(0,0,0))
  P2 <- cbind(diag(3),c(-1,0,0))
  rig <- aqt_rig_new(list(TOP=P1,SIDE=P2),optical_path="air_only")
  top <- aqt_tracks(data.frame(session_id="S",camera_id="TOP",
    track_id="A",time_s=c(0,.12345678901234,1),
    x=c(.5,.6,.75),y=.25))
  side <- aqt_tracks(data.frame(session_id="S",camera_id="SIDE",
    track_id="B",time_s=c(0,.001,1),
    x=c(.25,.4,.5),y=.25))
  pair <- data.frame(session_id="S",id_a="A",id_b="B",
    time_a_s=c(0,1),time_b_s=c(0,1),fish_id="fish")
  xyz <- aqt_reconstruct_3d(top,side,pair,rig)
  expect_equal(nrow(xyz),2)
  expect_equal(xyz$x,c(2,3),tolerance=1e-8)
})
