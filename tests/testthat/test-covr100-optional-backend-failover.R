# Testthat-recommended package-local namespace mocking; no global
# library unloading, machine-dependent missing packages or R options.
.cov100_mock_missing <- function(missing) {
  force(missing)
  function(package,quietly=TRUE,...) {
    if (identical(package,missing)) return(FALSE)
    base::requireNamespace(package,quietly=quietly,...)
  }
}

test_that("3D visualization gives actionable errors without optional rgl", {
  xyz <- aqt_simulate_tracks(n_fish=1L,n_frames=6L,
                             dimension=3L,seed=811L)
  voxel <- aqt_voxel_occupancy(xyz,
      breaks=list(x=c(-100,100),y=c(-100,100),z=c(-100,100)),
      by="group")
  ensemble <- aqt_trajectory_ensemble(xyz,sigma=.01,draws=20L,seed=511L)
  scene <- aqt_tank_scene_snapshot(xyz,frame_s=0,
                                   tail_s=0,max_age_s=.1)
  joint <- structure(list(tracks=list(xyz)),
                     class="aqt_joint_refractive_scenarios")
  cloud <- aqt_joint_scene_cloud(joint,session_id="S01",frame_s=0)
  testthat::local_mocked_bindings(
      requireNamespace=.cov100_mock_missing("rgl"),
      .package="aquaTrajectories")
  expect_error(aqt_plot_path3d(xyz),"rgl")
  expect_error(aqt_plot_school3d(xyz,"S01","SIM",0),"rgl")
  expect_error(aqt_plot_voxel3d(voxel),"rgl")
  expect_error(aqt_plot_ensemble3d(ensemble,"S01","SIM","fish1"),"rgl")
  expect_error(aqt_plot_tank_scene3d(scene),"rgl")
  expect_error(aqt_plot_joint_scene_cloud3d(cloud),"rgl")
})

test_that("sparse FPCA refuses absent optional backend without surrogate fitting", {
  tr <- aqt_simulate_tracks(n_fish=5L,n_frames=6L,dimension=2L,seed=913L)
  sparse <- aqt_sparse_fpca_input(tr)
  testthat::local_mocked_bindings(
     requireNamespace=.cov100_mock_missing("fdapace"),
     .package="aquaTrajectories")
  expect_error(aqt_sparse_fpca_fit(sparse),"Install optional fdapace")
})

test_that("mixed-effects models report missing nlme and splines backends explicitly", {
  hierarchical <- structure(data.frame(),
                            class=c("aqt_hierarchical_event_frame","data.frame"))
  functional <- structure(data.frame(),
     class=c("aqt_functional_longitudinal_frame","data.frame"))
  attr(functional,"aqt_design_strict") <- TRUE
  attr(functional,"aqt_time_grid") <- 0:6
  testthat::with_mocked_bindings({
    expect_error(aqt_hierarchical_event_fit(hierarchical),
                 "Install optional package nlme")
    expect_error(aqt_functional_longitudinal_fit(functional),
                 "Install optional nlme")
  },requireNamespace=.cov100_mock_missing("nlme"),
    .package="aquaTrajectories")
  if(base::requireNamespace("nlme",quietly=TRUE))
    testthat::with_mocked_bindings({
      expect_error(aqt_functional_longitudinal_fit(functional),
                   "Install R recommended splines")
    },requireNamespace=.cov100_mock_missing("splines"),
      .package="aquaTrajectories")
})

test_that("base raster graphics fallback is qualified without ragg installation", {
  if(!capabilities("png") || !capabilities("tiff"))
    testthat::skip("Base raster devices unavailable on this runner")
  parent <- tempfile("cov100_device_fallback_");dir.create(parent)
  on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
  target <- file.path(parent,"raster")
  testthat::local_mocked_bindings(
     requireNamespace=.cov100_mock_missing("ragg"),
     .package="aquaTrajectories")
  expect_invisible(aqt_figure_export(
    function() graphics::plot(1:5,1:5,main="synthetic"),
    target,formats=c("png","tiff"),width=3,height=3,dpi=100))
  expect_gt(file.info(file.path(target,"figure.png"))$size,100)
  expect_gt(file.info(file.path(target,"figure.tiff"))$size,100)
})

test_that("base SVG fallback works when native Cairo graphics is available", {
  if(identical(Sys.info()[["sysname"]],"Darwin") || !capabilities("cairo"))
    testthat::skip("Native SVG needs working Cairo, not guaranteed on macOS")
  parent <- tempfile("cov100_svg_fallback_");dir.create(parent)
  on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
  path <- file.path(parent,"svg")
  testthat::local_mocked_bindings(
     requireNamespace=.cov100_mock_missing("svglite"),
     .package="aquaTrajectories")
  expect_invisible(aqt_figure_export(
    function() graphics::plot(1:5,1:5,main="synthetic"),
    path,formats="svg",width=3,height=3))
  expect_gt(file.info(file.path(path,"figure.svg"))$size,100)
})
