test_that("reviewed flatport views reconstruct known time-stamped 3D fish paths", {
  make <- function(cx) aqt_flatport_camera(
    diag(3),diag(3),c(cx,0,-1),c(0,0,0),c(0,0,1),
    glass_thickness=.1,n_first=1,n_glass=1,n_water=1,
    units="cm")
  top <- aqt_tracks(data.frame(session_id="S",camera_id="TOP",
    track_id="A",time_s=0:3,x=c(.5,.6,.7,.8),y=0))
  side <- aqt_tracks(data.frame(session_id="S",camera_id="SIDE",
    track_id="B",time_s=(0:3)+.001,x=c(-.5,-.4,-.3,-.2),y=0))
  matched <- data.frame(session_id="S",id_a="A",id_b="B",
    time_a_s=0:3,time_b_s=(0:3)+.001,
    fish_id="F",tank_id="T1",treatment="control",
    reviewer="annotator",reason="fixture known")
  out <- aqt_refractive_reconstruct_tracks(
    top,side,matched,make(-1),make(1),max_skew_s=.01)
  expect_s3_class(out,"aqt_tracks")
  expect_equal(attr(out,"aqt_dimension"),3L)
  expect_equal(out$x,c(0,.2,.4,.6),tolerance=1e-9)
  expect_equal(out$y,rep(0,4),tolerance=1e-9)
  expect_equal(out$z,rep(1,4),tolerance=1e-9)
  expect_true(all(out$observed))
  expect_true(all(out$ray_separation<1e-9))
  expect_equal(unique(out$tank_id),"T1")
  expect_false(attr(out,"aqt_calibration_certified"))
  qc <- aqt_refractive_track_quality(out)
  expect_equal(qc$n_valid,4)
  expect_equal(qc$fraction_valid,1)
  expect_lt(qc$max_separation,1e-9)
  expect_equal(aqt_path_summary(out)$path_length,.6,tolerance=1e-9)
})

test_that("refractive track reconstruction preserves occlusion and strict clocks", {
  make <- function(x) aqt_flatport_camera(
    diag(3),diag(3),c(x,0,-1),c(0,0,0),c(0,0,1),
    glass_thickness=.1,n_first=1,n_glass=1,n_water=1)
  top <- aqt_tracks(data.frame(session_id="S",camera_id="TOP",
    track_id="A",time_s=0:2,x=c(.5,.6,.7),y=0,
    observed=c(TRUE,FALSE,TRUE)))
  side <- aqt_tracks(data.frame(session_id="S",camera_id="SIDE",
    track_id="B",time_s=0:2,x=c(-.5,-.4,-.3),y=0))
  pairs <- data.frame(session_id="S",id_a="A",id_b="B",
    time_a_s=0:2,time_b_s=0:2,fish_id="F")
  out <- aqt_refractive_reconstruct_tracks(top,side,pairs,
                                            make(-1),make(1))
  expect_equal(sum(out$observed),2)
  expect_true(is.na(out$x[2]))
  expect_equal(aqt_refractive_track_quality(out)$fraction_valid,2/3)
  expect_error(aqt_refractive_reconstruct_tracks(
      top,side,transform(pairs,time_b_s=c(.1,1,2)),
      make(-1),make(1),max_skew_s=.01),"skew")
  expect_error(aqt_refractive_reconstruct_tracks(
      top,side,rbind(pairs,pairs[1,,drop=FALSE]),
      make(-1),make(1)),"multiple fused")
})

test_that("camera units and source coordinate requirements are enforced", {
  x <- aqt_tracks(data.frame(session_id="S",camera_id="TOP",
    track_id="A",time_s=0,x=.5,y=0))
  y <- aqt_tracks(data.frame(session_id="S",camera_id="SIDE",
    track_id="B",time_s=0,x=-.5,y=0))
  pair <- data.frame(session_id="S",id_a="A",id_b="B",
    time_a_s=0,time_b_s=0,fish_id="F")
  make <- function(x,units) aqt_flatport_camera(
    diag(3),diag(3),c(x,0,-1),c(0,0,0),c(0,0,1),
    glass_thickness=.1,n_first=1,n_glass=1,n_water=1,
    units=units)
  expect_error(aqt_refractive_reconstruct_tracks(x,y,pair,
      make(-1,"cm"),make(1,"m")),"comparable")
  invalid <- aqt_tracks(as.data.frame(x),units="cm",
                        coordinate_system="tank")
  expect_error(aqt_refractive_reconstruct_tracks(invalid,y,pair,
      make(-1,"cm"),make(1,"cm")),"pixel-space")
})
