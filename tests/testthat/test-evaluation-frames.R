test_that("explicit frame scope excludes unannotated predictions for identity scoring", {
  truth <- data.frame(session_id="S1",camera_id="TOP",frame_id=0,
    track_id="A",x=0,y=0)
  predictions <- data.frame(session_id="S1",camera_id="TOP",
    frame_id=c(0,10),track_id=c("one","one"),x=c(0,100),y=c(0,0))
  full <- aqt_tracking_metrics(truth,predictions,max_distance=.1)
  expect_equal(full$false_positives,1)
  evaluated <- aqt_evaluation_frames(data.frame(session_id="S1",
    camera_id="TOP",frame_id=0))
  focused <- aqt_tracking_metrics(truth,predictions,max_distance=.1,
                                  evaluated_frames=evaluated)
  expect_equal(focused$false_positives,0)
  expect_equal(focused$IDF1,1)
  expect_equal(nrow(aqt_tracking_match(truth,predictions,max_distance=.1,
                                      evaluated_frames=evaluated)),1)
})

test_that("invalid or duplicated evaluation frames are rejected", {
  f <- data.frame(session_id="S1",camera_id="TOP",frame_id=0)
  expect_error(aqt_evaluation_frames(rbind(f,f)),"Duplicate")
  expect_error(aqt_evaluation_frames(transform(f,frame_id=NA)),"missing")
})
