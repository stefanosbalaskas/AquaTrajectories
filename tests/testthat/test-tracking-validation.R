test_that("global assignment finds optimal identity matching", {
  W <- matrix(c(5,5,6,0),nrow=2)
  assignment <- aquaTrajectories:::.aqt_max_assignment(W)
  expect_equal(assignment,c(2L,1L))
  expect_equal(sum(W[cbind(1:2,assignment)]),11)
})

test_that("perfect detections can hide one identity switch", {
  gt <- data.frame(session_id="S1",camera_id="TOP",
    frame_id=rep(0:2,2),track_id=rep(c("A","B"),each=3),
    x=c(0,1,2,10,11,12),y=0)
  pd <- gt
  pd$track_id <- c("1","1","3","2","2","2")
  out <- aqt_tracking_metrics(gt,pd,max_distance=.1)
  expect_equal(out$n_matches,6)
  expect_equal(out$false_positives,0)
  expect_equal(out$false_negatives,0)
  expect_equal(out$adjacent_id_switches,1)
  expect_equal(out$comparable_adjacent_pairs,4)
  expect_equal(out$IDTP,5)
  expect_equal(out$IDFP,1)
  expect_equal(out$IDFN,1)
  expect_equal(out$IDF1,5/6)
  expect_equal(out$position_rmse,0)
})

test_that("species mismatches prevent class-aware tracking matches", {
  gt <- data.frame(session_id="S1",camera_id="TOP",
    frame_id=0,track_id="A",x=0,y=0,class_id="seabass")
  pd <- transform(gt,class_id="seabream",track_id="1")
  expect_equal(nrow(aqt_tracking_match(gt,pd,max_distance=1)),0)
  expect_equal(nrow(aqt_tracking_match(gt,pd,max_distance=1,class_aware=FALSE)),1)
})

test_that("scopes cannot be combined across cameras", {
  gt <- data.frame(session_id=c("S1","S1"),camera_id=c("TOP","SIDE"),
    frame_id=c(0,0),track_id=c("A","A"),x=c(0,100),y=c(0,100))
  pd <- transform(gt,track_id="1")
  out <- aqt_tracking_metrics(gt,pd,max_distance=.1)
  expect_equal(nrow(out),2)
  expect_true(all(out$IDF1==1))
})

test_that("invalid observation contracts are rejected", {
  d <- data.frame(session_id="S1",camera_id="TOP",frame_id=c(1,1),
    track_id=c("A","A"),x=c(0,1),y=c(0,1))
  expect_error(aqt_tracking_observations(d),"Duplicate")
  expect_error(aqt_tracking_observations(transform(d,frame_id=c(.5,1))),
               "integer")
})
