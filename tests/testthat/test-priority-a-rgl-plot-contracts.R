# Optional graphics backend qualification -- execute the REAL rgl functions
# in a headless/null device, never substitute static projections for them.
# Rendering success cannot certify anatomical geometry or physical XYZ truth.
test_that("all six optional rgl plotting exports create native 3D scenes", {
  skip_if_not_installed("rgl")
  previous <- Sys.getenv("RGL_USE_NULL",unset=NA_character_)
  Sys.setenv(RGL_USE_NULL="TRUE")
  on.exit(if(is.na(previous)) Sys.unsetenv("RGL_USE_NULL")
          else Sys.setenv(RGL_USE_NULL=previous),add=TRUE)
  rgl::open3d(useNULL=TRUE)
  on.exit(rgl::close3d(),add=TRUE)

  tracks <- aqt_simulate_tracks(n_fish=3L,n_frames=9L,fps=10,
                                dimension=3L,seed=308L)
  path <- aqt_tracks(as.data.frame(tracks)[tracks$track_id=="fish1",],
                     units="cm",coordinate_system="tank")
  ensemble <- aqt_trajectory_ensemble(path,sigma=.1,draws=20L,seed=81L)
  expect_null(aqt_plot_path3d(path,max_gap_s=.11))
  expect_gt(length(rgl::ids3d()),0L)
  ids <- aqt_plot_ensemble3d(ensemble,"S01","SIM","fish1",n_draws=4L)
  expect_equal(length(ids),9L)
  school <- aqt_plot_school3d(tracks,"S01","SIM",time_s=.5,
                             label_ids=FALSE)
  expect_equal(nrow(school),3L)
  scene <- aqt_tank_scene_snapshot(tracks,frame_s=.5,tail_s=.2,
                                   max_age_s=.01,max_gap_s=.11)
  expect_s3_class(aqt_plot_tank_scene3d(scene),"aqt_tank_scene")

  breaks <- lapply(c("x","y","z"),function(axis) {
    ext <- range(path[[axis]])
    seq(ext[1]-.1,ext[2]+.1,length.out=4L)
  })
  names(breaks) <- c("x","y","z")
  vox <- aqt_voxel_occupancy(path,breaks=breaks,by="fish")
  expect_gt(nrow(aqt_plot_voxel3d(vox)),0L)
  d <- data.frame(track_id=rep(c("fish1","fish2"),each=4L),
                  x=rep(c(1,2),each=4)+rep(0:3/100,2),
                  y=rep(c(2,1),each=4)+rep(0:3/100,2),
                  z=rep(c(3,4),each=4)+rep(0:3/100,2))
  cloud <- structure(list(points=d,units="cm",frame_s=.5,n_draws=4L,
                summary=data.frame(track_id=c("fish1","fish2"))),
                class="aqt_joint_scene_cloud")
  expect_s3_class(aqt_plot_joint_scene_cloud3d(cloud),
                  "aqt_joint_scene_cloud")
  expect_gt(length(rgl::ids3d()),0L)
})
