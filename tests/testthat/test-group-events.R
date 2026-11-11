test_that("schooling with two parallel fish has known polarization", {
  d <- data.frame(session_id="S1",camera_id="top",
     track_id=rep(c("A","B"),each=2),
     time_s=c(0,1,0,1),x=c(0,1,0,1),y=c(0,0,2,2))
  x <- aqt_tracks(d,units="cm",coordinate_system="tank")
  g <- aqt_group_metrics(x)
  expect_equal(g$mean_nearest_neighbor,c(2,2))
  expect_true(is.na(g$polarization[1]))
  expect_equal(g$polarization[2],1)
})

test_that("event alignment records correct before during after states", {
  d <- data.frame(session_id="S1",time_s=c(1,5,7,11))
  e <- aqt_event_table(data.frame(session_id="S1",
    event_id="routine",start_s=5,end_s=7))
  out <- aqt_align_events(d,e)
  expect_equal(out$relative_time_s,c(-4,0,2,6))
  expect_equal(out$phase,c("before","during","during","after"))
  expect_equal(nrow(aqt_align_events(d,e,window_s=c(-2,3))),2)
})
