test_that("penalized fish mean change identifies known step exactly", {
  x <- data.frame(session_id="S1",camera_id="TOP",track_id="F",
    time_s=1:60,speed=c(rep(1,30),rep(3,30)))
  fit <- aqt_state_changepoint(x,outcome="speed",
    penalty=10,min_segment=5,max_gap_s=2)
  expect_s3_class(fit,"aqt_changepoints")
  expect_equal(fit$n_segments,2)
  expect_equal(fit$break_after_index,30L)
  expect_equal(fit$change_time_s,30.5)
  expect_equal(fit$segments$mean_value,c(1,3))
  expect_equal(fit$penalized_objective,10,tolerance=1e-10)
  expect_false(fit$empirical_significance_test)
  expect_equal(fit$fitted,x$speed)
  event <- data.frame(session_id="S1",event_id="feed",
     start_s=30,end_s=31)
  delay <- aqt_changepoint_event_delay(fit,event,max_delay_s=5)
  expect_equal(delay$delay_s,.5)
  expect_true(delay$has_change)
  none <- aqt_changepoint_event_delay(fit,event,max_delay_s=.1)
  expect_false(none$has_change)
  expect_true(is.na(none$delay_s))
})

test_that("strong penalty selects no change in a constant fish trace", {
  x <- data.frame(session_id="S1",camera_id="TOP",track_id="F",
    time_s=0:29,speed=rep(1,30))
  fit <- aqt_state_changepoint(x,penalty=5,min_segment=4)
  expect_equal(fit$n_segments,1)
  expect_length(fit$change_time_s,0)
  expect_equal(fit$segments$within_sse,0)
  expect_equal(fit$penalized_objective,0)
})

test_that("missing observations, duplicate timestamps and gaps are rejected", {
  x <- data.frame(session_id="S1",camera_id="TOP",track_id="F",
    time_s=1:20,speed=rep(1,20))
  y <- x
  y$speed[10] <- NA_real_
  expect_error(aqt_state_changepoint(y,penalty=3),
               "Missing/nonfinite")
  y <- x
  y$observed <- TRUE
  y$observed[10] <- FALSE
  expect_error(aqt_state_changepoint(y,penalty=3),
               "Non-observed")
  y <- x
  y$time_s[10] <- y$time_s[9]
  expect_error(aqt_state_changepoint(y,penalty=3),
               "Duplicate")
  y <- x
  y$time_s[11:20] <- y$time_s[11:20]+100
  expect_error(aqt_state_changepoint(y,penalty=3,max_gap_s=2),
               "gaps")
  y <- x
  y$track_id[20] <- "OTHER"
  expect_error(aqt_state_changepoint(y,penalty=3),
               "one scoped fish")
  expect_error(aqt_state_changepoint(x,penalty=-1),"penalty")
  expect_error(aqt_state_changepoint(x,penalty=1,min_segment=2),
               "min_segment")
})

test_that("change-point plots work in headless R PDF", {
  x <- data.frame(session_id="S",camera_id="TOP",track_id="F",
    time_s=0:39,speed=c(rep(0,20),rep(2,20)))
  fit <- aqt_state_changepoint(x,penalty=5)
  path <- tempfile(fileext=".pdf")
  grDevices::pdf(path)
  tryCatch(
    expect_s3_class(aqt_plot_changepoints(fit),"aqt_changepoints"),
    finally=grDevices::dev.off()
  )
  expect_true(file.exists(path))
  unlink(path)
})
