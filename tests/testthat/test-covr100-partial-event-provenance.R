# Fail-closed analysis regressions using two independent synthetic session
# clocks. No synchronized cameras, treatment effects or biological estimates.
.cov100_partial_event_review <- function() {
  sessions <- c("S1","S2")
  frames <- do.call(rbind,lapply(sessions,function(s)
    data.frame(session_id=s,camera_id="TOP",frame_id=0:4,
               time_s=(0:4)/10,width_px=100,height_px=100)))
  source <- do.call(rbind,lapply(sessions,function(s)
    data.frame(session_id=s,camera_id="TOP",track_id="F",
               frame_id=0:4,time_s=(0:4)/10,
               x=1:5,y=rep(3,5),observed=TRUE,
               detection_confidence=.95)))
  aqt_qc_review(aqt_trajectory_qc(source,frames,max_gap_s=.11))
}

test_that("research workflow reports missing logged events without inventing them", {
  review <- .cov100_partial_event_review()
  partial_log <- data.frame(session_id="S1",event_id="E1",
                            start_s=.2,end_s=.3)
  out <- aqt_research_analyze(
    review,profiles="functional",events=partial_log,
    config=list(event_clock="same_recording",
                functional_grid_s=c(-.1,0,.1)))
  row <- out$diagnostics[out$diagnostics$profile=="functional",]
  expect_identical(row$status, "failed")
  expect_match(row$reason,
               "All supplied fish sessions require an explicitly logged event")
  expect_null(out$functional)
  expect_false(out$provenance$physical_calibration_certified)
})

test_that("research event analysis keeps missing measurements as a visible status", {
  review <- .cov100_partial_event_review()
  future_log <- data.frame(session_id="S1",event_id="E1",
                           start_s=40,end_s=41)
  out <- aqt_research_analyze(
    review,profiles="events",events=future_log,
    config=list(event_clock="same_recording"))
  row <- out$diagnostics[out$diagnostics$profile=="events",]
  expect_true(row$status %in% c("failed","skipped"))
  expect_true(nzchar(row$reason))
  expect_null(out$events)
})
