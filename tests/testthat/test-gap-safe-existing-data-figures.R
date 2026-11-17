# Detector-independent analytical figure verification. All positions are
# invented exact-answer fixtures, not fish observations or biological truth.

test_that("2D display paths never bridge hidden rows or declared time gaps", {
  d <- data.frame(session_id="S01",camera_id="TOP",track_id="001",
    time_s=c(0,.1,.2,.3,.4,4,4.1),
    x=c(0,1,999,3,4,5,999),y=c(0,0,999,0,0,0,999),
    observed=c(TRUE,TRUE,FALSE,TRUE,TRUE,TRUE,FALSE))
  tracks <- aqt_tracks(d,units="px",coordinate_system="image")
  display <- as.data.frame(tracks)
  display$x[!display$observed] <- NA_real_
  display$y[!display$observed] <- NA_real_
  split_runs <- getFromNamespace(".aqt_observed_path_runs",
                                  "aquaTrajectories")
  actual <- unname(split_runs(display,max_gap_s=.25))
  expect_equal(actual,list(1:2,4:5,6L))
  # By contrast, legacy infinite-gap display would join rows 4--6.
  expect_equal(unname(split_runs(display,Inf)),list(1:2,4:6))
  f <- tempfile(fileext=".pdf")
  grDevices::pdf(f)
  tryCatch(expect_null(aqt_plot_paths(tracks,max_gap_s=.25)),
           finally=grDevices::dev.off())
  expect_gt(file.info(f)$size,1000)
  expect_error(aqt_plot_paths(tracks,max_gap_s=0),"max_gap_s")
  expect_error(aqt_plot_paths(tracks,max_gap_s=-1),"max_gap_s")
  expect_error(aqt_plot_paths(tracks,max_gap_s=NA_real_),"max_gap_s")
})

test_that("group kinematics and polarization match independent known answers", {
  d <- data.frame(session_id="S",camera_id="TOP",
    track_id=rep(c("A","B"),each=3L),time_s=rep(0:2,2L),
    x=c(0,1,2,0,1,0),y=c(0,0,0,3,3,3))
  tracks <- aqt_tracks(d,units="cm",coordinate_system="tank")
  g <- aqt_group_metrics(tracks,max_gap_s=1)
  expect_equal(g$time_s,0:2)
  expect_equal(g$n_visible,c(2L,2L,2L))
  expect_equal(g$centroid_x,c(0,1,1),tolerance=1e-12)
  expect_equal(g$centroid_y,rep(1.5,3L),tolerance=1e-12)
  expect_equal(g$mean_nearest_neighbor,c(3,3,sqrt(13)),tolerance=1e-12)
  # Both move east at t1; at t2 A moves east while B moves west.
  expect_true(is.na(g$polarization[1L]))
  expect_equal(g$polarization[2:3],c(1,0),tolerance=1e-12)
  geom <- aqt_group_spatial_summary(tracks)
  expect_equal(geom$group_extent,c(3,3,sqrt(13)),tolerance=1e-12)
  expect_equal(geom$radius_gyration,geom$group_extent/2,
               tolerance=1e-12)
  f <- tempfile(fileext=".pdf")
  grDevices::pdf(f)
  result <- tryCatch(aqt_plot_school_dynamics(geom,"S","TOP",
                       metric="group_extent"),
                     finally=grDevices::dev.off())
  expect_equal(result$group_extent,c(3,3,sqrt(13)),tolerance=1e-12)
  expect_gt(file.info(f)$size,1000)
})

test_that("unobserved fish are excluded from simultaneous geometry", {
  d <- data.frame(session_id="S",camera_id="TOP",time_s=0,
    track_id=c("A","B","C"),x=c(0,3,1000),y=c(0,4,1000),
    observed=c(TRUE,TRUE,FALSE))
  tracks <- aqt_tracks(d)
  g <- aqt_group_metrics(tracks)
  expect_equal(g$n_visible,2L)
  expect_equal(g$mean_nearest_neighbor,5)
  expect_equal(aqt_group_spatial_summary(tracks)$group_extent,5)
})
