test_that("trajectory IDs are scoped to camera and session", {
  d <- data.frame(session_id=c("S1","S1","S1","S2"),
    camera_id=c("top","top","side","top"),track_id="1",
    time_s=c(0,1,0,0),x=c(0,3,5,7),y=c(0,4,2,3))
  x <- aqt_tracks(d,units="cm",coordinate_system="tank")
  expect_s3_class(x,"aqt_tracks")
  expect_true(aqt_tracks_validate(x))
  expect_identical(attr(x,"aqt_dimension"),2L)
  expect_error(aqt_tracks(rbind(d,d[1,,drop=FALSE])),"Duplicate")
  expect_error(aqt_tracks(transform(d,x=c(NA,3,5,7))),"both")
})

test_that("path lengths use real timestamps and do not bridge gaps", {
  d <- data.frame(session_id="S1",camera_id="top",track_id="A",
    time_s=c(0,1,2,3),x=c(0,3,NA,4),y=c(0,4,NA,4))
  x <- aqt_tracks(d,units="cm",coordinate_system="tank")
  k <- aqt_kinematics(x,max_gap_s=1.2)
  expect_equal(k$step_distance[2],5)
  expect_equal(k$speed[2],5)
  expect_true(all(is.na(k$speed[3:4])))
  expect_equal(aqt_path_summary(x,max_gap_s=1.2)$path_length,5)
  qc <- aqt_track_qc(x,max_gap_s=.5,max_speed=4)
  expect_true(qc$large_gap[2])
  expect_true(qc$implausible_speed[2])
})

test_that("synthetic 3D trajectories are deterministic without changing RNG", {
  set.seed(2026); rng <- .Random.seed
  x <- aqt_simulate_tracks(n_fish=5,n_frames=10,dimension=3,seed=4)
  expect_identical(rng,.Random.seed)
  expect_equal(nrow(x),50)
  expect_identical(attr(x,"aqt_dimension"),3L)
  expect_equal(x,aqt_simulate_tracks(5,10,dimension=3,seed=4))
  expect_error(aqt_plot_path3d(aqt_simulate_tracks(dimension=2)),"True 3D")
})


test_that("interpolated/non-observed coordinates are not treated as measured movement", {
  d <- data.frame(session_id="S1",camera_id="top",track_id="A",
    time_s=c(0,1,2),x=c(0,1,10),y=c(0,0,0),observed=c(TRUE,TRUE,FALSE))
  tracks <- aqt_tracks(d)
  kin <- aqt_kinematics(tracks)
  expect_equal(kin$speed[2],1)
  expect_true(is.na(kin$speed[3]))
  expect_equal(aqt_path_summary(tracks)$path_length,1)
})


test_that("planar scale and zone occupancy have exact reference values", {
  d <- data.frame(session_id="S1",camera_id="TOP",track_id="fish1",
    time_s=0:3,x=c(0,10,20,30),y=c(0,0,0,0))
  x <- aqt_tracks(d)
  c <- aqt_scale_calibrate(x,pixels_per_cm=10)
  expect_equal(c$x,c(0,1,2,3))
  expect_equal(c$x_px,d$x)
  expect_equal(aqt_kinematics(c)$speed[2],1)
  zones <- data.frame(zone_id="left",xmin=-1,xmax=1,ymin=-1,ymax=1)
  v <- aqt_zone_occupancy(c,zones)
  expect_equal(v$n_in_zone,2)
  expect_equal(v$sample_fraction,.5)
  expect_error(aqt_scale_calibrate(c,10),"2D pixel-space")
})
