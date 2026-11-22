# Synthetic independent tracking identities; no TrackEval/HOTA parity claim.
.cov100_tracking_gt <- function() {
 data.frame(session_id="S",camera_id="C",frame_id=0:1,
    track_id="T",x=c(0,1),y=0,class_id="fish")
}
.cov100_tracking_pr <- function() {
 d <- .cov100_tracking_gt()
 d$track_id <- "P"
 d
}
test_that("tracking observations allow empty annotated frames but reject invalid tracks",{
 gt <- .cov100_tracking_gt()
 expect_error(aqt_tracking_observations(list()),"data must be a data frame")
 bad <- gt;bad$track_id[1] <- ""
 expect_error(aqt_tracking_observations(bad),"Invalid tracking identity")
 bad <- gt;bad$frame_id[1] <- -1
 expect_error(aqt_tracking_observations(bad),"frame_id must")
 bad <- gt;bad$frame_id[1] <- 1.5
 expect_error(aqt_tracking_observations(bad),"frame_id must")
 bad <- gt;bad$x[1] <- Inf
 expect_error(aqt_tracking_observations(bad),"Tracking coordinates must")
 bad <- gt;bad$class_id[1] <- ""
 expect_error(aqt_tracking_observations(bad),"class_id must")
 bad <- rbind(gt,gt[1,,drop=FALSE])
 expect_error(aqt_tracking_observations(bad),"Duplicate track ID within")
 no_label <- gt[0,setdiff(names(gt),"class_id"),drop=FALSE]
 empty <- aqt_tracking_observations(no_label)
 expect_equal(nrow(empty),0L)
 expect_true("class_id" %in% names(empty))
 expect_equal(length(empty$class_id),0L)
})
test_that("tracking matching and IDF1 handle empty references, class mismatch and switches",{
 gt <- .cov100_tracking_gt();pd <- .cov100_tracking_pr()
 expect_error(aqt_tracking_match(gt,pd,max_distance=0),"max_distance")
 expect_error(aqt_tracking_match(gt,pd,max_distance=Inf),"max_distance")
 expect_error(aqt_tracking_match(gt,pd,max_distance=2,class_aware=NA),
              "class_aware must")
 m <- aqt_tracking_match(gt,pd,max_distance=2)
 expect_equal(nrow(m),2L)
 expect_equal(m$distance,c(0,0),tolerance=1e-12)
 unmatched <- pd
 unmatched$class_id <- "other"
 expect_equal(nrow(aqt_tracking_match(gt,unmatched,max_distance=2)),0L)
 unscoped <- aqt_tracking_match(gt,unmatched,max_distance=2,class_aware=FALSE)
 expect_equal(nrow(unscoped),2L)
 empty_gt <- gt[0,,drop=FALSE]
 empty_pd <- pd[0,,drop=FALSE]
 expect_equal(nrow(aqt_tracking_match(empty_gt,pd,max_distance=2)),0L)
 expect_equal(nrow(aqt_tracking_match(gt,empty_pd,max_distance=2)),0L)
 expect_equal(nrow(aqt_tracking_metrics(empty_gt,empty_pd,max_distance=2)),0L)
 only_predictions <- aqt_tracking_metrics(empty_gt,pd,max_distance=2)
 expect_equal(only_predictions$n_truth,0)
 expect_true(is.na(only_predictions$tracking_recall))
 only_truth <- aqt_tracking_metrics(gt,empty_pd,max_distance=2)
 expect_equal(only_truth$n_pred,0)
 expect_true(is.na(only_truth$tracking_precision))
 good <- aqt_tracking_metrics(gt,pd,max_distance=2)
 expect_equal(good$IDF1,1,tolerance=1e-12)
 expect_equal(good$adjacent_id_switches,0)
 switch <- pd
 switch$track_id[2] <- "P2"
 switched <- aqt_tracking_metrics(gt,switch,max_distance=2)
 expect_equal(switched$adjacent_id_switches,1)
 expect_equal(switched$comparable_adjacent_pairs,1)
 expect_false(isTRUE(attr(switched,"official_HOTA")))
})
test_that("assignment weight validation and source matching remain deterministic",{
 assign <- aquaTrajectories:::.aqt_max_assignment
 expect_equal(length(assign(matrix(numeric(),0,2))),0L)
 expect_error(assign(matrix(-1,1,1)),"nonnegative finite assignment")
 expect_error(assign(matrix(Inf,1,1)),"nonnegative finite assignment")
 weights <- matrix(c(3,0,0,4),nrow=2)
 expect_equal(assign(weights),1:2)
 rectangular <- matrix(c(3,1,2,4,1,0),nrow=2)
 mapped <- assign(rectangular)
 expect_equal(length(mapped),2L)
 expect_true(length(unique(mapped))==2L)
})
