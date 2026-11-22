# Event-inference failures are not statistical replications. This file
# exercises genuine design constraints and boundaries using synthetic tables.

.cov100_epoch_inputs <- function() {
  d <- data.frame(session_id="S",camera_id="C",track_id="0001",
    time_s=c(-2,-1,0,1,2,3),speed=c(2,3,5,7,9,11),
    observed=rep(TRUE,6),stringsAsFactors=FALSE)
  ev <- data.frame(session_id="S",event_id="E",start_s=0,end_s=0)
  list(data=d,events=ev,windows=list(pre=c(-2,0),post=c(0,3)))
}
.cov100_tank_epochs <- function() {
  data.frame(tank_id=rep(c("C1","C2","T1","T2"),each=2),
      treatment=rep(c("control","control","treatment","treatment"),each=2),
      epoch=rep(c("baseline","response"),4),
      value=c(5,6,5,7,5,8,5,9),stringsAsFactors=FALSE)
}

test_that("epoch API rejects missing numerical, clock, source-unit and interval evidence", {
  z <- .cov100_epoch_inputs()
  call <- function(data=z$data,windows=z$windows,...)
    aqt_event_epoch_summary(data,z$events,"speed",windows=windows,...)
  expect_error(call(data=data.frame(x=1)),"Missing session, time")
  bad <- z$data;bad$speed <- letters[1:6]
  expect_error(call(data=bad),"numeric column")
  bad <- z$data;bad$time_s[1] <- Inf
  expect_error(call(data=bad),"time_s must be finite numeric")
  expect_error(call(unit_cols="session_id"),"Invalid unit_cols")
  expect_error(call(unit_cols=c("track_id","track_id")),"Invalid unit_cols")
  bad <- z$data;bad$session_id[1] <- NA_character_
  expect_error(call(data=bad),"Missing session identifiers")
  bad <- z$data;bad$track_id[1] <- ""
  expect_error(call(data=bad),"Unit identifiers")
  expect_error(call(windows=1),"windows must be a named list")
  expect_error(call(windows=list(c(-1,0))),"windows must be a named list")
  expect_error(call(windows=list(pre=c(1,0))),"finite increasing limits")
  expect_error(call(windows=list(pre=c(-Inf,0))),"finite increasing limits")
  expect_error(call(windows=list(post=c(0,1),pre=c(-1,0))),"chronological")
  expect_error(call(windows=list(pre=c(-2,1),post=c(0,3))),"not overlap")
  expect_error(call(min_points=0),"positive integer")
  expect_error(call(min_points=1.3),"positive integer")
  expect_error(call(max_gap_s=0),"must be positive")
  expect_equal(nrow(call(data=transform(z$data,session_id="absent"))),0L)
})

test_that("sample and time-weighted evidence never bridge missing intervals", {
  z <- .cov100_epoch_inputs()
  d <- z$data
  d$time_s <- 0:5
  e <- z$events
  windows <- list(short=c(0,1),long=c(1,5))
  s <- aqt_event_epoch_summary(d,e,"speed",windows=windows,
                estimator="sample_mean",min_points=1)
  expect_equal(nrow(s),2L)
  expect_equal(s$observed_span_s[1],0)
  expect_equal(s$n_valid[1],1)
  duplicate <- d
  duplicate$time_s[2] <- duplicate$time_s[1]
  expect_error(aqt_event_epoch_summary(duplicate,e,"speed",
          windows=list(all=c(0,5)),estimator="time_weighted"),
          "unique timestamps")
  no_data <- d
  no_data$observed <- FALSE
  t <- aqt_event_epoch_summary(no_data,e,"speed",
         windows=list(all=c(0,5)),estimator="time_weighted",min_points=2)
  expect_true(is.na(t$value))
  expect_equal(t$observed_span_s,0)
  no_data$observed <- TRUE
  no_data$speed[2] <- NA_real_
  r <- aqt_event_epoch_summary(no_data,e,"speed",
      windows=list(all=c(0,5)),estimator="time_weighted",
      max_gap_s=1,min_points=2)
  expect_true(is.finite(r$value))
  expect_lt(r$observed_span_s,5)
  sparse <- aqt_event_epoch_summary(d,e,"speed",
       windows=list(all=c(0,5)),estimator="time_weighted",
       max_gap_s=.01,min_points=2)
  expect_true(is.na(sparse$value))
  expect_equal(sparse$observed_span_s,0)
  point <- aqt_event_epoch_summary(d,e,"speed",
       windows=list(point=c(0,.1)),min_points=1)
  expect_equal(point$observed_span_s,0)
  expect_equal(point$value,2)
})

test_that("tank-level audit explicitly refuses pseudo-replication and unusable treatment design", {
  d <- .cov100_tank_epochs()
  expect_error(aqt_design_audit(NULL),"Missing treatment/tank")
  expect_error(aqt_design_audit(d[0,,drop=FALSE]),"No experimental observations")
  bad <- d;bad$tank_id[1] <- ""
  expect_error(aqt_design_audit(bad),"nonmissing")
  bad <- d;bad$tank_id[1] <- NA_character_
  expect_error(aqt_design_audit(bad),"nonmissing")
  bad <- d;bad$treatment[1] <- "treatment"
  expect_error(aqt_design_audit(bad),"varies within tank")
  expect_equal(aqt_design_audit(d)$n_tanks,c(2,2))
  expect_error(aqt_tank_event_contrast(NULL),"Missing tank")
  expect_error(aqt_tank_event_contrast(transform(d,value=as.character(value))),
        "value column must be numeric")
  expect_error(aqt_tank_event_contrast(d,treatment_levels="control"),
        "exactly two")
  expect_error(aqt_tank_event_contrast(d,treatment_levels=c("control","control")),
        "exactly two")
  expect_error(aqt_tank_event_contrast(d,baseline="response"),
        "Distinct baseline")
  expect_error(aqt_tank_event_contrast(d,draws=99),"integer >=100")
  expect_error(aqt_tank_event_contrast(d,level=0),"level must")
  expect_error(aqt_tank_event_contrast(d,seed=-1),"Invalid seed")
  expect_error(aqt_tank_event_contrast(d,treatment_levels=c("control","other")),
        "two declared treatment levels")
  bad <- d;bad$value[bad$tank_id=="C1" & bad$epoch=="baseline"] <- NA_real_
  expect_error(aqt_tank_event_contrast(bad),"finite baseline and response")
  # Evaluated units are four tanks, not eight rows/observations.
  fit <- aqt_tank_event_contrast(d,draws=100,seed=83)
  expect_equal(fit$n_tanks_control,2)
  expect_equal(fit$n_tanks_treatment,2)
  expect_equal(fit$estimate,2)
  expect_false(fit$causal_identification)
})
