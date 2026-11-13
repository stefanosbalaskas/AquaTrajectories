.aqt_storyboard_test_track <- function() {
  aqt_tracks(data.frame(session_id="S1",camera_id="FUSED3D",
    track_id="F1",time_s=0:4,x=0:4,
    y=rep(0,5),z=rep(1,5),observed=rep(TRUE,5)),
    units="cm",coordinate_system="tank")
}

test_that("four 3D panels report only observed physical movement", {
  tracks <- .aqt_storyboard_test_track()
  file <- tempfile(fileext=".pdf")
  grDevices::pdf(file,width=11,height=8)
  tryCatch({
    summary <- aqt_plot_trajectory_storyboard3d(
      tracks,times_s=c(0,1,2,4),recent_s=1,max_gap_s=1.1,
      tank_limits=list(x=c(0,22),y=c(0,8),z=c(0,11)))
    expect_s3_class(summary,"data.frame")
    expect_equal(summary$panel,LETTERS[1:4])
    expect_equal(summary$observed_distance,c(0,1,2,4))
    expect_equal(summary$latest_segment_speed,c(NA_real_,1,1,1))
    expect_true(all(summary$current_position_observed))
    expect_true(all(summary$session_id=="S1"))
    expect_equal(attr(summary,"aqt_units"),"cm")
    expect_false(attr(summary,"tank_bounds_from_observations"))
    expect_false(attr(summary,"independent_calibration_certified"))
  },finally=grDevices::dev.off())
  expect_true(file.exists(file))
  unlink(file)
})

test_that("missing observations and long gaps cannot manufacture paths", {
  d <- as.data.frame(.aqt_storyboard_test_track())
  d$observed[d$time_s==2] <- FALSE
  d[d$time_s==2,c("x","y","z")] <- NA_real_
  tracks <- aqt_tracks(d,units="cm",coordinate_system="tank")
  f <- tempfile(fileext=".pdf")
  grDevices::pdf(f)
  tryCatch({
    stats <- aqt_plot_trajectory_storyboard3d(
      tracks,times_s=c(0,1,2,4),recent_s=1,max_gap_s=1.1,
      max_age_s=0)
    expect_equal(stats$observed_distance,c(0,1,1,2))
    expect_false(stats$current_position_observed[3])
    expect_true(stats$current_position_observed[4])
    expect_equal(stats$latest_segment_speed[3],NA_real_)
    expect_true(attr(stats,"tank_bounds_from_observations"))
    none <- aqt_plot_trajectory_storyboard3d(
      tracks,times_s=c(0,1,2,4),max_gap_s=.5)
    expect_equal(none$observed_distance,rep(0,4))
  },finally=grDevices::dev.off())
  unlink(f)
})

test_that("storyboard rejects 2D, ambiguity and fabricated tank dimensions", {
  xyz <- .aqt_storyboard_test_track()
  d <- as.data.frame(xyz)
  uv <- aqt_tracks(d[,setdiff(names(d),"z"),drop=FALSE],
                   units="cm",coordinate_system="tank")
  expect_error(aqt_plot_trajectory_storyboard3d(uv),"physical XYZ")
  many <- aqt_tracks(rbind(d,transform(d,track_id="F2")),
                     units="cm",coordinate_system="tank")
  expect_error(aqt_plot_trajectory_storyboard3d(many),"exactly one")
  expect_error(aqt_plot_trajectory_storyboard3d(
    xyz,times_s=c(0,2,1,4)),"strictly increasing")
  expect_error(aqt_plot_trajectory_storyboard3d(
    xyz,times_s=c(0,1,2,5)),"in-range")
  expect_error(aqt_plot_trajectory_storyboard3d(
    xyz,tank_limits=list(x=c(0,2),y=c(0,8),z=c(0,11))),
    "outside tank_limits")
  expect_error(aqt_plot_trajectory_storyboard3d(
    xyz,track_id="NOT_A_FISH"),"no records")
})
