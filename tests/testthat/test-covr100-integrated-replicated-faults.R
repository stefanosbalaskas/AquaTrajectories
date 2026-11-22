# Independently replicated *synthetic* tank fixtures for failure-path
# classification in integrated R scientific workflows.
.cov100_experimental_review <- function(n_tanks=6L) {
  names <- paste0("T",seq_len(n_tanks))
  records <- lapply(seq_along(names),function(i) {
    session <- names[i]
    frame <- data.frame(session_id=session,camera_id="TOP",
      frame_id=0:9,time_s=(0:9)/10,width_px=100,height_px=100)
    obs <- do.call(rbind,lapply(1:2,function(fish) {
      t <- (0:9)/10
      data.frame(session_id=session,camera_id="TOP",
         frame_id=0:9,time_s=t,track_id=paste0("F",fish),
         x=10+fish+3*t+.05*i*sin(t*10+fish),
         y=10+fish+2*t+.02*i*cos(t*5+fish),
         observed=TRUE,detection_confidence=.95)
    }))
    list(frames=frame,observations=obs)
  })
  f <- do.call(rbind,lapply(records,`[[`,"frames"))
  o <- do.call(rbind,lapply(records,`[[`,"observations"))
  design <- data.frame(session_id=names,camera_id="TOP",tank_id=names,
    treatment=ifelse(seq_along(names)<=n_tanks/2,"control","treatment"))
  ev <- data.frame(session_id=names,event_id="EVENT",start_s=.5,end_s=.5)
  list(review=aqt_qc_review(aqt_trajectory_qc(o,f,max_gap_s=.11)),
       design=design,events=ev)
}

test_that("experimental analysis reports an estimator failure for unsupported epochs", {
  x <- .cov100_experimental_review(4L)
  result <- aqt_research_analyze(
     x$review,profiles="experimental",events=x$events,design=x$design,
     config=list(event_clock="same_recording",
       treatment_levels=c("control","treatment"),
       experimental_contrast=TRUE,
       event_windows=list(baseline=c(-.4,0),response=c(0,.4)),
       event_min_points=100L,experimental_draws=100L))
  status <- result$diagnostics[
     result$diagnostics$profile=="experimental",,drop=FALSE]
  expect_identical(status$status,"failed")
  expect_match(status$reason,"finite baseline and response observations")
  expect_false(result$provenance$fish_identity_certified)
  expect_null(result$statistical_models$tank_contrast)
})

test_that("functional tank sensitivity records incomplete support without inventing fish", {
  x <- .cov100_experimental_review(4L)
  result <- aqt_research_analyze(
     x$review,profiles=c("functional","experimental"),
     events=x$events,design=x$design,
     config=list(event_clock="same_recording",
       treatment_levels=c("control","treatment"),
       experimental_contrast=FALSE,functional_contrast=TRUE,
       functional_grid_s=seq(-.3,.6,by=.1),
       functional_max_gap_s=.11,experimental_draws=100L))
  expect_identical(result$diagnostics$status[
      result$diagnostics$profile=="functional"],"complete")
  expect_true(is.character(
       result$statistical_models$functional_contrast_error))
  expect_null(result$statistical_models$functional_contrast)
  expect_false(result$provenance$physical_calibration_certified)
})

test_that("strict longitudinal integrated workflow attempts qualified nested model", {
  if (!requireNamespace("nlme",quietly=TRUE))
    testthat::skip("Optional nlme not installed")
  x <- .cov100_experimental_review(6L)
  result <- aqt_research_analyze(
     x$review,profiles=c("functional","experimental"),
     events=x$events,design=x$design,
     config=list(event_clock="same_recording",
       treatment_levels=c("control","treatment"),
       experimental_contrast=FALSE,
       functional_model="nested_nlme",
       functional_grid_s=seq(-.3,.3,by=.1),
       functional_max_gap_s=.11))
  expect_identical(result$diagnostics$status[
      result$diagnostics$profile=="functional"],"complete")
  model <- result$statistical_models$functional_model
  if (!is.null(model)) {
    expect_s3_class(model,"aqt_functional_longitudinal_fit")
    expect_equal(model$n_tanks,6L)
    expect_false(model$causal_identification)
  } else {
    expect_true(nzchar(result$statistical_models$functional_model_error))
  }
})
