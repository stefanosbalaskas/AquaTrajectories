# Functional support is a documented recording/event join, not a
# fabricated clock resynchronisation or extrapolation to another session.
test_that("unmatched independent event sessions cannot create functional fish curves",{
 measurements <- data.frame(session_id="S",camera_id="C",
      track_id="F",time_s=0:5,speed=seq_len(6),
      observed=TRUE)
 events <- data.frame(session_id="OTHER",event_id="E",
      start_s=2,end_s=2)
 expect_error(aqt_functional_event_grid(
       measurements,events,outcome="speed",grid_s=seq(-1,1,by=.5),
       max_gap_s=1.1),
       "No fish sessions match the supplied event log")
})
