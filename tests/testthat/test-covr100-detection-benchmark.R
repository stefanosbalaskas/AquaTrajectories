# Synthetic detector benchmark: independent manually supplied rectangles.
# AP is conventional 101-point interpolation, not a claimed COCO score.
.cov100_det_truth <- function() data.frame(
 session_id="S",camera_id="TOP",frame_id=c(0,0),
 class_id="fish",xmin=c(0,20),ymin=c(0,20),xmax=c(10,30),ymax=c(10,30))
.cov100_det_pred <- function() {
 x <- rbind(.cov100_det_truth(),
   data.frame(session_id="S",camera_id="TOP",frame_id=0,class_id="fish",
       xmin=100,ymin=100,xmax=110,ymax=110))
 x$confidence <- c(.9,.8,.1)
 x
}
test_that("detection boxes and IoU validate original geometry before scoring", {
 gt <- .cov100_det_truth()
 pd <- .cov100_det_pred()
 expect_error(aqt_detection_boxes(data.frame(x=1)),"must be a data frame")
 expect_error(aqt_detection_boxes(pd[,setdiff(names(pd),"confidence")],
               "prediction"),"Predictions require confidence")
 bad <- pd;bad$confidence[1] <- 1.5
 expect_error(aqt_detection_boxes(bad,"prediction"),"Predictions require confidence")
 bad <- gt;bad$class_id[1] <- ""
 expect_error(aqt_detection_boxes(bad),"must be nonmissing")
 bad <- gt;bad$xmin[1] <- NA_real_
 expect_error(aqt_detection_boxes(bad),"finite numbers")
 bad <- gt;bad$xmax[1] <- bad$xmin[1]
 expect_error(aqt_detection_boxes(bad),"Degenerate or inverted")
 bad <- gt;bad$ymax[1] <- 0
 expect_error(aqt_detection_boxes(bad),"Degenerate or inverted")
 expect_error(aqt_box_iou(data.frame(x=1),gt),"must be a data frame")
 bad <- gt;bad$xmin <- as.character(bad$xmin)
 expect_error(aqt_box_iou(bad,gt),"finite numeric")
 bad <- gt;bad$xmax[1] <- 0
 expect_error(aqt_box_iou(bad,gt),"Degenerate bounding box")
 overlap <- aqt_box_iou(gt,pd)
 expect_equal(dim(overlap),c(2L,3L))
 expect_equal(overlap[1,1],1)
 expect_equal(overlap[1,3],0)
 empty <- aqt_box_iou(gt,pd[0,,drop=FALSE])
 expect_equal(dim(empty),c(2L,0L))
})
test_that("detection matching reports all TP, FP and FN without frame pseudoreplication", {
 gt <- .cov100_det_truth();pd <- .cov100_det_pred()
 expect_error(aqt_detection_match(gt,pd,iou_threshold=0),"iou_threshold")
 expect_error(aqt_detection_match(gt,pd,iou_threshold=1.1),"iou_threshold")
 expect_error(aqt_detection_match(gt,pd,confidence_threshold=-1),"confidence_threshold")
 expect_error(aqt_detection_match(gt,pd,confidence_threshold=2),"confidence_threshold")
 both <- aqt_detection_match(gt,pd,confidence_threshold=0)
 expect_equal(sum(both$status=="TP"),2)
 expect_equal(sum(both$status=="FP"),1)
 expect_equal(sum(both$status=="FN"),0)
 no_pred <- aqt_detection_match(gt,pd[0,,drop=FALSE])
 expect_equal(sum(no_pred$status=="FN"),2)
 no_truth <- aqt_detection_match(gt[0,,drop=FALSE],pd)
 expect_equal(sum(no_truth$status=="FP"),3)
 none <- aqt_detection_match(gt[0,,drop=FALSE],pd[0,,drop=FALSE])
 expect_equal(nrow(none),0L)
 score <- aqt_detection_metrics(gt,pd,confidence_threshold=0)
 expect_equal(score$TP[score$class_id=="ALL"],2)
 expect_equal(score$FP[score$class_id=="ALL"],1)
 expect_true(is.finite(score$F1[score$class_id=="ALL"]))
 missed <- aqt_detection_metrics(gt,pd[0,,drop=FALSE])
 expect_true(is.na(missed$precision[missed$class_id=="ALL"]))
 expect_equal(missed$recall[missed$class_id=="ALL"],0)
})
test_that("average precision validates thresholds, absent classes and micro/macro scope", {
 gt <- .cov100_det_truth();pd <- .cov100_det_pred()
 expect_error(aqt_detection_ap(gt,pd,iou_thresholds=numeric()),"Invalid IoU")
 expect_error(aqt_detection_ap(gt,pd,iou_thresholds=0),"Invalid IoU")
 expect_error(aqt_detection_ap(gt,pd,iou_thresholds=c(.5,Inf)),"Invalid IoU")
 s <- aqt_detection_ap(gt,pd,iou_thresholds=c(.5,.75))
 expect_equal(nrow(s),2L)
 expect_equal(s$AP,c(1,1),tolerance=1e-12)
 empty <- aqt_detection_ap(gt[0,,drop=FALSE],pd[0,,drop=FALSE],.5)
 expect_equal(nrow(empty),0L)
 no_prediction <- aqt_detection_ap(gt,pd[0,,drop=FALSE],.5)
 expect_equal(no_prediction$AP,0)
 no_truth <- aqt_detection_ap(gt[0,,drop=FALSE],pd,.5)
 expect_true(all(is.na(no_truth$AP)))
 macro <- aqt_detection_map(gt,pd,iou_thresholds=c(.5,.75))
 expect_equal(macro$mean_AP,1,tolerance=1e-12)
 no_classes <- aqt_detection_map(gt[0,,drop=FALSE],pd[0,,drop=FALSE],.5)
 expect_true(is.na(no_classes$mean_AP))
 no_reference <- aqt_detection_map(gt[0,,drop=FALSE],pd,.5)
 expect_true(is.na(no_reference$mean_AP))
 expect_equal(nrow(no_reference$by_threshold),1)
})
