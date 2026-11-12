.aqt_annotation_sample_fixture <- function() {
  top <- data.frame(session_id="trial1",camera_id="TOP",
                    frame_id=0:29,time_s=(0:29)*.1,
                    width_px=1920,height_px=1080)
  side <- transform(top,camera_id="SIDE",time_s=time_s+.025)
  aqt_frame_manifest(rbind(top,side))
}

test_that("time-stratified annotation plan ignores detector results and preserves RNG", {
  frames <- .aqt_annotation_sample_fixture()
  set.seed(765)
  previous <- .Random.seed
  x <- aqt_annotation_frame_plan(frames,
     per_video=6L,strata=3L,seed=23L)
  expect_identical(.Random.seed,previous)
  y <- aqt_annotation_frame_plan(frames,
     per_video=6L,strata=3L,seed=23L)
  expect_equal(x,y)
  expect_s3_class(x,"aqt_annotation_plan")
  expect_equal(nrow(x),12)
  expect_equal(sum(x$camera_id=="TOP"),6)
  expect_equal(sum(x$camera_id=="SIDE"),6)
  expect_true(all(x$annotation_status=="planned_not_annotated"))
  expect_true(all(x$selection_probability==.2))
  expect_true(all(x$inverse_selection_probability==5))
  expect_equal(nrow(aqt_evaluation_frames(x)),12)
  expect_false(attr(x,"aqt_annotation_source_verified"))
  expect_false(attr(x,"aqt_annotations_completed"))
  expect_equal(sort(unique(x$temporal_stratum)),1:3)
  expect_equal(length(unique(paste(x$camera_id,x$frame_id))),12)
})

test_that("sampling audit reports acquired-frame, not fish-based, denominators", {
  frames <- .aqt_annotation_sample_fixture()
  plan <- aqt_annotation_frame_plan(frames,
    per_video=9L,strata=3L,seed=13L)
  a <- aqt_annotation_plan_audit(plan,frames)
  expect_s3_class(a,"aqt_annotation_plan_audit")
  expect_equal(nrow(a$per_video),2)
  expect_equal(a$per_video$n_acquired,c(30,30))
  expect_equal(a$per_video$n_planned,c(9,9))
  expect_equal(a$per_video$n_fully_annotated,c(0,0))
  expect_equal(a$per_video$planning_fraction,c(.3,.3))
  expect_equal(nrow(a$per_stratum),6)
  expect_true(all(a$per_stratum$n_acquired==10))
  expect_true(all(a$per_stratum$n_selected==3))
  expect_false(a$independent_human_annotations_verified)
  expect_false(a$animal_welfare_or_model_accuracy_certified)
  partly <- plan
  partly$annotation_status[1:4] <- "fully_annotated"
  audit2 <- aqt_annotation_plan_audit(partly,frames)
  expect_equal(sum(audit2$per_video$n_fully_annotated),4)
  expect_equal(sum(audit2$per_video$n_planned),18)
  expect_true(audit2$sampling_is_prediction_independent_by_software_design)
})

test_that("sampling fails when temporal bins have missing acquired footage", {
  sparse <- aqt_frame_manifest(data.frame(
    session_id="S",camera_id="TOP",frame_id=0:5,
    time_s=c(0,.01,.02,10,10.01,10.02),
    width_px=100,height_px=80))
  expect_error(aqt_annotation_frame_plan(sparse,
    per_video=3L,strata=3L),
    "Too few acquired frames")
  f <- .aqt_annotation_sample_fixture()
  expect_error(aqt_annotation_frame_plan(f,per_video=31,strata=3),
               "fewer acquired frames")
  expect_error(aqt_annotation_frame_plan(f,per_video=1,strata=1),
               "Require >=2")
  expect_error(aqt_annotation_frame_plan(f,per_video=4,strata=5),
               "Require >=2")
  expect_error(aqt_annotation_frame_plan(f,per_video=4,strata=2,
                                          seed=NA_real_),"nonnegative integer")
})

test_that("annotation-plan audit fails on reused IDs, time corruption and weights", {
  frames <- .aqt_annotation_sample_fixture()
  plan <- aqt_annotation_frame_plan(frames,
    per_video=6L,strata=3L,seed=11L)
  repeated <- rbind(plan,plan[1,,drop=FALSE])
  expect_error(aqt_annotation_plan_audit(repeated,frames),
               "Duplicate sampled annotation frame")
  wrong_time <- plan
  wrong_time$time_s[1] <- wrong_time$time_s[1]+.08
  expect_error(aqt_annotation_plan_audit(wrong_time,frames),
               "do not match acquired video")
  wrong_weight <- plan
  wrong_weight$selection_probability[1] <- .9
  expect_error(aqt_annotation_plan_audit(wrong_weight,frames),
               "contradict acquired video")
  wrong_status <- plan
  wrong_status$annotation_status[1] <- "unreviewed"
  expect_error(aqt_annotation_plan_audit(wrong_status,frames),
               "Annotation status")
})

test_that("planned unannotated video frames cannot be scored as human ground truth", {
  f <- aqt_frame_manifest(data.frame(
    session_id="S1",camera_id="TOP",frame_id=0:5,
    time_s=(0:5)*.1,width_px=100,height_px=80))
  empty_path <- tempfile(fileext=".mot.txt")
  file.create(empty_path)
  on.exit(unlink(empty_path),add=TRUE)
  tracks <- aqt_import_mot(empty_path,f,
    session_id="S1",camera_id="TOP")
  bundle <- structure(list(frames=f,tracks=tracks,
      output_sha256_verified=TRUE),class="aqt_video_bundle")
  plan <- aqt_annotation_frame_plan(f,
    per_video=4L,strata=2L,seed=15L)
  expect_error(aqt_video_bundle_benchmark(
    bundle,data.frame(),data.frame(),plan),
    "fully_annotated")
  reviewed <- plan
  reviewed$annotation_status <- "fully_annotated"
  expect_error(aqt_video_bundle_benchmark(
    bundle,data.frame(),data.frame(),reviewed),
    "data frame with")
})
