.aqt_dropout_example <- function() {
  d <- data.frame(session_id="tank_session",
                  camera_id="TOP",track_id="fish1",
                  time_s=0:19,x=as.numeric(0:19),
                  y=rep(0,20))
  aqt_tracks(d)
}

test_that("dropout preserves every source timestamp and exact input scope", {
  x <- .aqt_dropout_example()
  zero <- aqt_detection_dropout_scenarios(x,p_missing=0,
                                          persistence=.7,draws=10,seed=5)
  expect_s3_class(zero,"aqt_detection_dropout_scenarios")
  expect_length(zero$tracks,10)
  expect_true(all(zero$coverage$remaining_observed==20))
  expect_true(all(zero$coverage$additional_missed==0))
  expect_false(zero$assumptions$input_detection_rate_independently_calibrated)
  expect_false(zero$assumptions$interval_coverage_calibrated)
  for (s in zero$tracks) {
    expect_equal(as.data.frame(s)$time_s,as.data.frame(x)$time_s)
    expect_equal(as.data.frame(s)$x,as.data.frame(x)$x)
  }
})

test_that("Markov dropout is reproducible, does not restore missing fish", {
  x <- .aqt_dropout_example()
  src <- as.data.frame(x)
  src$observed[5] <- FALSE
  src$x[5] <- NA_real_; src$y[5] <- NA_real_
  x <- aqt_tracks(src)
  set.seed(123)
  before <- get(".Random.seed",envir=.GlobalEnv)
  a <- aqt_detection_dropout_scenarios(x,.45,persistence=.8,
                                       draws=20L,seed=25L)
  after <- get(".Random.seed",envir=.GlobalEnv)
  expect_identical(before,after)
  b <- aqt_detection_dropout_scenarios(x,.45,persistence=.8,
                                       draws=20L,seed=25L)
  expect_equal(a$coverage,b$coverage)
  expect_equal(as.data.frame(a$tracks[[1]]),
               as.data.frame(b$tracks[[1]]))
  expect_true(all(vapply(a$tracks,
     function(z) !as.data.frame(z)$observed[5],logical(1))))
  expect_true(all(vapply(a$tracks,
     function(z) is.na(as.data.frame(z)$x[5]),logical(1))))
  expect_true(any(a$coverage$additional_missed>0))
  expect_true(all(a$coverage$remaining_observed<=19))
  expect_equal(a$assumptions$transition_p01,.45*(1-.8))
  expect_equal(a$assumptions$transition_p11,.45+.8*(1-.45))
})

test_that("event kinematics respect dropout and flag conditional inferences", {
  x <- .aqt_dropout_example()
  scenarios <- aqt_detection_dropout_scenarios(x,0,draws=12L,seed=10L)
  events <- data.frame(session_id="tank_session",
                       event_id="feed",start_s=10,end_s=10)
  out <- aqt_detection_event_sensitivity(scenarios,events,outcome="speed",
     windows=list(baseline=c(-3,0),response=c(0,3)),min_points=1)
  expect_equal(sort(unique(out$draw)),1:12)
  expect_true(all(is.finite(out$value)))
  expect_true(all(abs(out$value-1)<1e-12))
  expect_false(attr(out,"aqt_intervals_calibrated"))
  expect_false(attr(out,"aqt_tank_effect_identified"))
})

test_that("invalid sensitivity claims or massive matrices fail closed", {
  x <- .aqt_dropout_example()
  expect_error(aqt_detection_dropout_scenarios(x,-.01),"Invalid p_missing")
  expect_error(aqt_detection_dropout_scenarios(x,.5,persistence=1),
               "Invalid persistence")
  expect_error(aqt_detection_dropout_scenarios(x,.5,draws=1.2),
               "integers")
  expect_error(aqt_detection_dropout_scenarios(x,.5,draws=1001),
               "Invalid draws")
  expect_error(aqt_detection_dropout_scenarios(x,.5,seed=-3),
               "Invalid seed")
  expect_error(aqt_detection_event_sensitivity(list(),data.frame()),
               "Expected detection dropout scenarios")
})
