test_that("rgl renderers accept color through plot3d col argument", {
  skip_if_not_installed("rgl")
  old <- Sys.getenv("RGL_USE_NULL",unset=NA_character_)
  Sys.setenv(RGL_USE_NULL="TRUE")
  on.exit({
    if (is.na(old)) Sys.unsetenv("RGL_USE_NULL")
    else Sys.setenv(RGL_USE_NULL=old)
  },add=TRUE)
  rgl::open3d(useNULL=TRUE)
  on.exit(rgl::close3d(),add=TRUE)
  d <- do.call(rbind,lapply(c("A","B"),function(id)
    data.frame(session_id="S1",camera_id="WORLD",
      track_id=id,time_s=0:4,x=0:4,
      y=if(id=="A") rep(0,5) else rep(1,5),
      z=1+(0:4)*.1,observed=TRUE)))
  tr <- aqt_tracks(d,units="cm",coordinate_system="tank")
  expect_error(aqt_plot_school3d(tr,"S1","WORLD",2),NA)
  vox <- aqt_voxel_occupancy(tr,
    list(x=seq(0,5),y=seq(0,3),z=seq(0,3)),by="fish")
  # Multiple voxels generate a vector of point sizes. The original
  # plot3d(size = vector) failed; scalar-size batching must draw these.
  expect_error(aqt_plot_voxel3d(
    vox[vox$track_id=="A",,drop=FALSE]),NA)
  uneven <- data.frame(
    session_id=rep("S1",3L),camera_id=rep("WORLD",3L),
    track_id=rep("A",3L),x_mid=c(0,1,2),
    y_mid=c(0,0,0),z_mid=c(1,1,1),
    n_samples=c(1L,3L,6L),
    sample_fraction=c(.1,.3,.6))
  expect_error(aqt_plot_voxel3d(uneven),NA)
  ensemble <- aqt_trajectory_ensemble(tr,sigma=.01,draws=20L)
  expect_error(aqt_plot_ensemble3d(
    ensemble,"S1","WORLD","A",n_draws=3L),NA)
})
