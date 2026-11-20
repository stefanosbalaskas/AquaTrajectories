testthat::test_that("frame-index analysis never fabricates timestamps or bridges gaps",{
  f <- data.frame(data_path=rep("reference",4),session_id="s",
                  camera_id="c",frame_id=0:3,width_px=100,
                  height_px=100,time_s=NA_real_)
  o <- data.frame(data_path="reference",session_id="s",camera_id="c",
      frame_id=c(0,1,3),track_id="001",x=c(10,13,40),y=c(10,14,50))
  a <- aqt_frame_index_analyze(f,o)
  testthat::expect_equal(a$summary$n_adjacent_frame_steps,1)
  testthat::expect_equal(a$summary$n_unbridged_within_track_gaps,1)
  testthat::expect_equal(a$observations$step_distance_px[2],5)
  testthat::expect_true(is.na(a$observations$step_distance_px[3]))
  testthat::expect_equal(a$summary$n_frames_without_observations,1)
  testthat::expect_false("speed" %in% names(a$observations))
  bad <- f;bad$time_s <- (0:3)/15
  testthat::expect_error(aqt_frame_index_analyze(bad,o),"time-aware")
  bad <- o;bad$frame_id[3] <- 1
  testthat::expect_error(aqt_frame_index_analyze(f,bad),"Duplicate")
  bad <- o;bad$x[1] <- 101
  testthat::expect_error(aqt_frame_index_analyze(f,bad),"outside")
})

testthat::test_that("path identities cannot mix reference and model",{
  f <- expand.grid(data_path=c("reference","model"),frame_id=0:1,
      KEEP.OUT.ATTRS=FALSE,stringsAsFactors=FALSE)
  f$session_id <- "s";f$camera_id <- "c"
  f$width_px <- 100;f$height_px <- 100;f$time_s <- NA_real_
  o <- data.frame(data_path=c("reference","reference","model","model"),
     session_id="s",camera_id="c",frame_id=c(0,1,0,1),track_id="01",
     x=c(0,3,60,60),y=c(0,4,50,52))
  a <- aqt_frame_index_analyze(f,o)
  testthat::expect_equal(a$summary$n_adjacent_frame_steps,c(1,1))
  testthat::expect_equal(sort(a$summary$observed_path_sum_px),c(2,5))
  testthat::expect_true(all(a$summary$n_local_track_labels==1))
  testthat::expect_true(all(a$group_geometry$n_visible==1L))
})
