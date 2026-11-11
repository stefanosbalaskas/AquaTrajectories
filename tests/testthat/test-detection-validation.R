test_that("bounding box contract and IoU are correct", {
  ref <- data.frame(session_id="S1",camera_id="top",frame_id="0",
    class_id="seabass",xmin=0,ymin=0,xmax=2,ymax=2)
  pred <- transform(ref,confidence=.9)
  expect_equal(aqt_box_iou(ref,pred)[1,1],1)
  moved <- transform(pred,xmin=1,xmax=3)
  expect_equal(aqt_box_iou(ref,moved)[1,1],1/3)
  expect_error(aqt_detection_boxes(transform(ref,xmax=0)),"Degenerate")
  expect_error(aqt_detection_boxes(transform(pred,confidence=1.5),
                                    role="prediction"),"confidence")
})

test_that("one missed fish and one false fish yield known F1", {
  gt <- data.frame(session_id="S1",camera_id="top",frame_id="5",
    class_id="fish",xmin=c(0,10),ymin=c(0,10),
    xmax=c(2,12),ymax=c(2,12))
  pd <- data.frame(session_id="S1",camera_id="top",frame_id="5",
    class_id="fish",xmin=c(0,20),ymin=c(0,20),
    xmax=c(2,22),ymax=c(2,22),confidence=c(.95,.75))
  out <- aqt_detection_metrics(gt,pd,iou_threshold=.5,confidence_threshold=.5)
  all <- out[out$class_id=="ALL",]
  expect_equal(c(all$TP,all$FP,all$FN),c(1,1,1))
  expect_equal(c(all$precision,all$recall,all$F1),c(.5,.5,.5))
  match <- aqt_detection_match(gt,pd)
  expect_equal(sort(match$status),c("FN","FP","TP"))
})

test_that("multispecies evaluations require class agreement", {
  gt <- data.frame(session_id="S1",camera_id="top",frame_id="5",
    class_id="seabass",xmin=0,ymin=0,xmax=2,ymax=2)
  pd <- transform(gt,class_id="seabream",confidence=.9)
  out <- aqt_detection_metrics(gt,pd,confidence_threshold=0)
  all <- out[out$class_id=="ALL",]
  expect_equal(all$TP,0)
  expect_equal(all$FP,1)
  expect_equal(all$FN,1)
})

test_that("confidence-ranked AP uses independent reference boxes", {
  gt <- data.frame(session_id="S1",camera_id="top",frame_id="0",
    class_id="fish",xmin=0,ymin=0,xmax=2,ymax=2)
  pd <- transform(gt,confidence=.99)
  ap <- aqt_detection_ap(gt,pd,iou_thresholds=c(.5,.75))
  expect_equal(ap$AP,c(1,1))
  no_hit <- transform(pd,xmin=10,xmax=12)
  expect_equal(aqt_detection_ap(gt,no_hit,iou_thresholds=.5)$AP,0)
  expect_equal(aqt_detection_ap(gt,pd,iou_thresholds=.5)$n_truth,1)
})

test_that("cardinality matching can recover two pairs rather than greedy one", {
  weights <- matrix(c(.8,.9,.6,.1),nrow=2)
  selected <- aquaTrajectories:::.aqt_cardinality_match(weights,.5)
  expect_equal(selected,c(2L,1L))
})


test_that("sparse reference annotations never penalize unseen frames", {
  gt <- data.frame(session_id="S1",camera_id="TOP",frame_id="0",
    class_id="fish",xmin=0,ymin=0,xmax=2,ymax=2)
  pd <- data.frame(session_id="S1",camera_id="TOP",frame_id="1",
    class_id="fish",xmin=0,ymin=0,xmax=2,ymax=2,confidence=.9)
  frames <- aqt_evaluation_frames(data.frame(session_id="S1",
                      camera_id="TOP",frame_id="0"))
  without_scope <- aqt_detection_metrics(gt,pd,confidence_threshold=0)
  expect_equal(without_scope$FP[without_scope$class_id=="ALL"],1)
  with_scope <- aqt_detection_metrics(gt,pd,confidence_threshold=0,
                                      evaluated_frames=frames)
  expect_equal(with_scope$FP[with_scope$class_id=="ALL"],0)
  expect_equal(with_scope$FN[with_scope$class_id=="ALL"],1)
  expect_error(aqt_detection_metrics(gt,pd,evaluated_frames=
       data.frame(session_id="S1",camera_id="TOP",frame_id="1")),
       "outside")
})


test_that("macro AP correctly averages classes with reference data", {
  gt <- data.frame(session_id="S1",camera_id="top",frame_id="0",
    class_id=c("seabass","seabream"),xmin=c(0,10),ymin=0,
    xmax=c(2,12),ymax=2)
  pred <- transform(gt,confidence=.9)
  res <- aqt_detection_map(gt,pred,iou_thresholds=c(.5,.75))
  expect_equal(res$mean_AP,1)
  expect_equal(res$by_threshold$mAP,c(1,1))
  expect_equal(nrow(res$by_class),4)
})
