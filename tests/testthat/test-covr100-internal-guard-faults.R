# All injections are test-scoped, and intentionally represent
# invalid subordinate-module outputs rather than actual fish or calibration.
test_that("second optical interface rejects a grazing upstream ray",{
  camera <- aqt_flatport_camera(
    K=diag(3),R_c2w=diag(3),center=c(0,0,-1),
    glass_front_point=c(0,0,0),glass_normal=c(0,0,1),
    glass_thickness=.1,n_first=1,n_glass=1,n_water=1,
    units="cm")
  fake_rays <- function(camera,pixels) {
    data.frame(origin_x=0,origin_y=0,origin_z=0,
      dir_x=1,dir_y=0,dir_z=0,valid=TRUE)
  }
  testthat::with_mocked_bindings({
    ray <- aqt_flatport_rays(camera,matrix(c(0,0),ncol=2))
    expect_false(ray$valid[1L])
    expect_true(all(is.na(unlist(ray[1L,1:6]))))
  },aqt_refractive_rays=fake_rays,
    .package="aquaTrajectories")
})

test_that("HMM posterior overflow is rejected after a finite mocked likelihood",{
  testthat::with_mocked_bindings({
    expect_error(aquaTrajectories:::.aqt_hmm_segment_decode(
      y=rep(1e308,3),means=c(0,8),sds=c(.5,.5),
      transition=matrix(c(.9,.1,.1,.9),2,2,byrow=TRUE),
      initial=c(.5,.5)),
      "HMM posterior normalization failed")
  },.aqt_hmm_lse=function(x) 0,
    .package="aquaTrajectories")
})

test_that("scene cloud prevents duplicate identity evidence from a mocked scene provider",{
  tr <- aqt_simulate_tracks(n_fish=1L,n_frames=6L,
                           dimension=3L,seed=912L)
  scenarios <- structure(list(tracks=list(tr)),
      class="aqt_joint_refractive_scenarios")
  fake_scene <- function(...) {
    list(heads=data.frame(track_id=c("F","F"),
      session_id="S01",camera_id="SIM",time_s=c(0,0),
      x=c(1,2),y=c(1,2),z=c(1,2),age_s=c(0,0)))
  }
  testthat::with_mocked_bindings({
    expect_error(aqt_joint_scene_cloud(scenarios,"S01",0),
                 "Multiple fish positions for one assigned label")
  },aqt_tank_scene_snapshot=fake_scene,
    .package="aquaTrajectories")
})

test_that("sparse FPCA rejects a degenerate common time axis before estimator use",{
  invalid <- structure(list(Lt=list(rep(2,3),rep(2,3))),
        class="aqt_sparse_fpca_input")
  expect_error(aqt_sparse_fpca_design_audit(invalid,bins=5),
               "Common design time range is zero")
})

test_that("publication gallery detects unexpected public API shape",{
  testthat::with_mocked_bindings({
    expect_error(aqt_viz2_gallery(),
                 "Public plot inventory changed")
  },getNamespaceExports=function(ns) character(0),
    .package="aquaTrajectories")
})
