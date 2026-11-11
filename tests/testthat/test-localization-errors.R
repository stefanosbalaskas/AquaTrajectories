test_that("independently matched camera positions yield signed residuals", {
  truth <- data.frame(session_id="S1",camera_id="TOP",
    frame_id=0:2,track_id="fishA",x=c(0,1,2),y=c(0,0,0))
  pred <- transform(truth,track_id="ID9",
    x=c(.2,1.1,2.3),y=c(.1,-.1,0))
  errors <- aqt_tracking_position_errors(
    truth,pred,max_distance=1)
  expect_equal(nrow(errors),3)
  expect_equal(errors$error_x,c(.2,.1,.3),tolerance=1e-12)
  expect_equal(errors$error_y,c(.1,-.1,0),tolerance=1e-12)
  summary <- aqt_tracking_position_error_summary(errors)
  expect_equal(summary$bias_x,.2,tolerance=1e-12)
  expect_equal(summary$bias_y,0,tolerance=1e-12)
  expect_equal(summary$rmse_x,sqrt(mean(c(.2,.1,.3)^2)))
  expect_equal(summary$n_matched,3)
})

test_that("unannotated frames are excluded from reference residuals", {
  truth <- data.frame(session_id="S1",camera_id="TOP",
    frame_id=0,track_id="A",x=0,y=0)
  pred <- data.frame(session_id="S1",camera_id="TOP",
    frame_id=c(0,10),track_id="X",x=c(.1,100),y=0)
  frames <- aqt_evaluation_frames(data.frame(session_id="S1",
     camera_id="TOP",frame_id=0))
  e <- aqt_tracking_position_errors(truth,pred,max_distance=2,
                                     evaluated_frames=frames)
  expect_equal(nrow(e),1)
  expect_equal(e$error_x,.1)
  expect_true(is.na(aqt_tracking_position_error_summary(e)$sd_x))
})


test_that("sparse-frame residuals use correctly filtered source indices", {
  truth <- data.frame(session_id="S",camera_id="TOP",
    frame_id=10,track_id="A",x=10,y=0)
  pred <- data.frame(session_id="S",camera_id="TOP",
    frame_id=c(0,10),track_id="P",x=c(100,10.2),y=c(100,.3))
  evaluated <- aqt_evaluation_frames(data.frame(
    session_id="S",camera_id="TOP",frame_id=10))
  residual <- aqt_tracking_position_errors(truth,pred,
    max_distance=1,evaluated_frames=evaluated)
  expect_equal(nrow(residual),1)
  expect_equal(residual$error_x,.2,tolerance=1e-12)
  expect_equal(residual$error_y,.3,tolerance=1e-12)
})
