# Acquired frame PTS sampling is independent of model predictions,
# never proof that planned frames were actually annotated by a human.
.cov100_annotation_source <- function(irregular=FALSE) {
 n <- 12L
 d <- data.frame(session_id="S",camera_id="C",
     frame_id=0:(n-1L),time_s=seq(0,by=.1,length.out=n),
     width_px=640,height_px=480)
 if(irregular)d$time_s[12] <- 100
 aqt_frame_manifest(d)
}
test_that("frame sampling prevents thinning unobserved source-video strata",{
 m <- .cov100_annotation_source()
 expect_error(aqt_annotation_frame_plan(data.frame()),"Expected aqt_frame_manifest")
 expect_error(aqt_annotation_frame_plan(m,per_video=1),"Require >=2")
 expect_error(aqt_annotation_frame_plan(m,per_video=2,strata=1),"Require >=2")
 expect_error(aqt_annotation_frame_plan(m,per_video=3,strata=4),"Require >=2")
 expect_error(aqt_annotation_frame_plan(m,per_video=2.5),"positive integers")
 expect_error(aqt_annotation_frame_plan(m,strata=Inf),"positive integers")
 expect_error(aqt_annotation_frame_plan(m,seed=-1),"nonnegative integer")
 expect_error(aqt_annotation_frame_plan(m,seed=2^31),"nonnegative integer")
 expect_error(aqt_annotation_frame_plan(m,per_video=13,strata=2),
              "fewer acquired frames")
 uneven <- .cov100_annotation_source(irregular=TRUE)
 expect_error(aqt_annotation_frame_plan(uneven,per_video=6,strata=3),
              "Too few acquired frames in at least one time stratum")
 set.seed(21);before <- .Random.seed
 p <- aqt_annotation_frame_plan(m,per_video=5,strata=2,seed=22)
 expect_identical(.Random.seed,before)
 expect_s3_class(p,"aqt_annotation_plan")
 expect_equal(nrow(p),5L)
 expect_true(all(p$annotation_status=="planned_not_annotated"))
 expect_equal(sum(p$selection_probability[p$temporal_stratum==1]>0),3)
 expect_false(attr(p,"aqt_annotations_completed"))
 expect_equal(p$selection_probability*p$inverse_selection_probability,
              rep(1,5),tolerance=1e-12)
 again <- aqt_annotation_frame_plan(m,per_video=5,strata=2,seed=22)
 expect_identical(p,again)
})
test_that("annotation plan audit rejects altered clocks, frames and inclusion weights",{
 m <- .cov100_annotation_source()
 p <- aqt_annotation_frame_plan(m,per_video=6,strata=3,seed=23)
 expect_error(aqt_annotation_plan_audit(list(),m),"Expected aqt_annotation_plan")
 expect_error(aqt_annotation_plan_audit(p,data.frame()),
              "Expected original aqt_frame_manifest")
 bad <- p
 bad <- rbind(bad,bad[1,,drop=FALSE])
 class(bad) <- class(p)
 expect_error(aqt_annotation_plan_audit(bad,m),"Duplicate sampled")
 bad <- p
 bad$frame_id[1] <- 100
 expect_error(aqt_annotation_plan_audit(bad,m),
              "do not match acquired video")
 bad <- p
 bad$time_s[1] <- bad$time_s[1]+.1
 expect_error(aqt_annotation_plan_audit(bad,m),
              "do not match acquired video")
 bad <- p;bad$annotation_status[1] <- "computer_predicted"
 expect_error(aqt_annotation_plan_audit(bad,m),
              "Annotation status must")
 bad <- p;bad$annotation_status[1] <- NA_character_
 expect_error(aqt_annotation_plan_audit(bad,m),
              "Annotation status must")
 bad <- p;bad$temporal_stratum[1] <- 0L
 expect_error(aqt_annotation_plan_audit(bad,m),
              "Temporal annotation strata must")
 bad <- p;bad$stratum_end_s <- NULL
 expect_error(aqt_annotation_plan_audit(bad,m),
              "Missing temporal stratum endpoints")
 bad <- p;bad$selection_probability[1] <- 0
 expect_error(aqt_annotation_plan_audit(bad,m),
              "Invalid frame sampling probabilities")
 bad <- p;bad$inverse_selection_probability[1] <- Inf
 expect_error(aqt_annotation_plan_audit(bad,m),
              "Invalid frame sampling probabilities")
 bad <- p;bad$stratum_end_s[1] <- bad$stratum_start_s[1]
 expect_error(aqt_annotation_plan_audit(bad,m),
              "Invalid temporal stratum bounds")
 bad <- p;bad$n_stratum_available[1] <- bad$n_stratum_available[1]+1L
 expect_error(aqt_annotation_plan_audit(bad,m),
              "Annotation sample counts or inclusion weights")
 bad <- p;bad$selection_probability[1] <- .9
 expect_error(aqt_annotation_plan_audit(bad,m),
              "Annotation sample counts or inclusion weights")
 q <- aqt_annotation_plan_audit(p,m)
 expect_equal(q$per_video$n_planned,6L)
 expect_equal(q$per_video$n_fully_annotated,0L)
 expect_false(q$independent_human_annotations_verified)
 complete <- p;complete$annotation_status[] <- "fully_annotated"
 reviewed <- aqt_annotation_plan_audit(complete,m)
 expect_equal(reviewed$per_video$n_fully_annotated,6L)
 expect_false(reviewed$independent_human_annotations_verified)
})
