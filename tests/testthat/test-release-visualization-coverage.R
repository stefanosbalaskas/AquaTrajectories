# Synthetic-only release-candidate regression tests. Never use private fish data.

test_that("public 2D path plotter renders observed positions headlessly", {
  tracks <- aqt_tracks(data.frame(
    session_id=rep("S",6),camera_id=rep("TOP",6),
    track_id=rep(c("A","B"),each=3),
    time_s=rep(c(0,1,2),2),
    x=c(0,1,2,3,4,5),y=c(1,2,1,3,2,4),
    observed=TRUE))
  filepath <- tempfile(fileext=".pdf")
  grDevices::pdf(filepath)
  on.exit({
    grDevices::dev.off()
    unlink(filepath)
  },add=TRUE)
  expect_null(aqt_plot_paths(tracks))
  expect_true(file.exists(filepath))
  missing <- as.data.frame(tracks)
  missing$x <- missing$y <- NA_real_
  missing$observed <- FALSE
  expect_error(aqt_plot_paths(aqt_tracks(missing)),"No valid positions")
})

test_that("3D plotters reject unqualified scene and cloud objects", {
  expect_error(aqt_plot_tank_scene3d(list()),
               "Expected a physical 3D")
  expect_error(aqt_plot_joint_scene_cloud3d(list()),
               "Expected an aqt_joint_scene_cloud")
  empty <- structure(list(
    points=data.frame(track_id=character(),x=numeric(),
                      y=numeric(),z=numeric()),
    units="cm"),class="aqt_joint_scene_cloud")
  expect_error(aqt_plot_joint_scene_cloud3d(empty),
               "No observed 3D positions")
})

test_that("optional rgl renders actual synthetic XYZ scene and uncertainty cloud", {
  skip_if_not_installed("rgl")
  old <- Sys.getenv("RGL_USE_NULL",unset=NA_character_)
  Sys.setenv(RGL_USE_NULL="TRUE")
  on.exit({
    if (is.na(old)) Sys.unsetenv("RGL_USE_NULL")
    else Sys.setenv(RGL_USE_NULL=old)
  },add=TRUE)
  rgl::open3d(useNULL=TRUE)
  on.exit(rgl::close3d(),add=TRUE)

  d <- data.frame(
    session_id=rep("S",6),camera_id=rep("FUSED3D",6),
    track_id=rep(c("A","B"),each=3),
    time_s=rep(0:2,2),
    x=c(0,1,2,4,5,6),
    y=c(0,1,2,2,3,4),
    z=c(1,1.1,1.2,2,2.1,2.2),
    observed=TRUE)
  tracks <- aqt_tracks(d,units="cm",coordinate_system="tank")
  scene <- aqt_tank_scene_snapshot(
    tracks,frame_s=2,tail_s=2,max_age_s=0,max_gap_s=1.1)
  expect_s3_class(aqt_plot_tank_scene3d(scene),"aqt_tank_scene")

  second <- as.data.frame(tracks)
  second$x <- second$x+.05
  draw2 <- aqt_tracks(second,units="cm",coordinate_system="tank")
  scenarios <- structure(
    list(tracks=list(tracks,draw2)),
    class="aqt_joint_refractive_scenarios")
  cloud <- aqt_joint_scene_cloud(scenarios,"S",frame_s=2,max_age_s=0)
  expect_s3_class(aqt_plot_joint_scene_cloud3d(cloud),
                  "aqt_joint_scene_cloud")
  expect_false(cloud$coverage_calibrated)
  expect_false(cloud$posterior_claim)
})
