test_that("named event windows give known sample and time-weighted means", {
  d <- data.frame(session_id="S1",camera_id="TOP",track_id="A",
    time_s=c(-2,-1,0,1,2,3),
    speed=c(2,2,4,6,8,10),observed=TRUE)
  e <- data.frame(session_id="S1",event_id="routine",
    start_s=0,end_s=0)
  w <- list(baseline=c(-2,0),response=c(0,2),recovery=c(2,3))
  a <- aqt_event_epoch_summary(d,e,"speed",windows=w,
                                estimator="sample_mean")
  expect_equal(a$epoch,c("baseline","response","recovery"))
  expect_equal(a$value,c(2,5,9))
  b <- aqt_event_epoch_summary(d,e,"speed",windows=w,
                                estimator="time_weighted")
  expect_equal(b$value,c(2,5,9))
  expect_true(all(b$n_valid==2))
  expect_error(aqt_event_epoch_summary(d,e,"speed",
    windows=list(response=c(0,2),baseline=c(-2,0))),"chronological")
})

test_that("missing and non-observed samples interrupt time-weighted estimates", {
  d <- data.frame(session_id="S1",camera_id="TOP",track_id="A",
     time_s=0:3,speed=c(2,NA,10,10),
     observed=c(TRUE,TRUE,TRUE,TRUE))
  e <- data.frame(session_id="S1",event_id="E",
    start_s=0,end_s=0)
  w <- list(response=c(0,3))
  r <- aqt_event_epoch_summary(d,e,"speed",windows=w,
    estimator="time_weighted",max_gap_s=1.5)
  expect_equal(r$value,10)
  expect_equal(r$observed_span_s,1)
  expect_equal(r$n_valid,3)
  d$observed[3] <- FALSE
  r2 <- aqt_event_epoch_summary(d,e,"speed",windows=w,
    estimator="time_weighted",max_gap_s=1.5)
  expect_true(is.na(r2$value))
  expect_equal(r2$observed_span_s,0)
})

test_that("between-tank inference respects independent tank replication", {
  d <- data.frame(
    tank_id=rep(c("C1","C2","T1","T2"),each=2),
    treatment=rep(c("control","control","treatment","treatment"),each=2),
    epoch=rep(c("baseline","response"),4),
    value=c(5,6,5,7,5,8,5,9))
  audit <- aqt_design_audit(d)
  expect_equal(audit$n_tanks,c(2,2))
  expect_true(all(audit$replicated))
  set.seed(111)
  saved <- .Random.seed
  fit <- aqt_tank_event_contrast(d,draws=200,seed=81)
  expect_identical(.Random.seed,saved)
  expect_equal(fit$estimate,2)
  expect_equal(c(fit$n_tanks_control,fit$n_tanks_treatment),c(2,2))
  expect_equal(fit,aqt_tank_event_contrast(d,draws=200,seed=81))
  expect_gte(fit$lower,1)
  expect_lte(fit$upper,3)
  expect_false(fit$causal_identification)
  reduced <- d[d$tank_id!="T2",,drop=FALSE]
  expect_error(aqt_tank_event_contrast(reduced,draws=200),
               "two independent tanks")
  d$treatment[1] <- "treatment"
  expect_error(aqt_design_audit(d),"varies within tank")
})

test_that("tank-level paired changes can be graphed to PDF", {
  d <- data.frame(tank_id=rep(c("C1","C2","T1","T2"),each=2),
    treatment=rep(c("control","control","treatment","treatment"),each=2),
    epoch=rep(c("baseline","response"),4),
    value=c(5,6,5,7,5,8,5,9))
  fit <- aqt_tank_event_contrast(d,draws=100,seed=3)
  path <- tempfile(fileext=".pdf")
  grDevices::pdf(path)
  tryCatch({
    x <- aqt_plot_tank_changes(fit)
    expect_equal(nrow(x),4)
  },finally=grDevices::dev.off())
  expect_true(file.exists(path))
  unlink(path)
})
