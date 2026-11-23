# Avoid treating two near-identical physical capture times as a single
# observed functional target. No interpolation may change the event clock.
test_that("functional alignment refuses two floating-point-close source samples for one target",{
  d <- data.frame(session_id="S",camera_id="C",track_id="F",
      time_s=c(1,1+1e-15,2),speed=c(1,2,3),observed=TRUE)
  ev <- data.frame(session_id="S",event_id="E",start_s=1,end_s=1)
  expect_error(aqt_functional_event_grid(
          d,ev,"speed",grid_s=c(0,.5),max_gap_s=1),
          "Ambiguous near-identical frame times")
})
test_that("functional alignment requires one independently logged event per session",{
  d <- data.frame(session_id="S",camera_id="C",track_id="F",
      time_s=0:3,speed=1:4,observed=TRUE)
  ev <- data.frame(session_id=c("S","S"),event_id=c("E1","E2"),
                   start_s=c(1,2),end_s=c(1,2))
  expect_error(aqt_functional_event_grid(d,ev,"speed",
      grid_s=c(0,1),max_gap_s=1.1),"One event per session is required")
});
