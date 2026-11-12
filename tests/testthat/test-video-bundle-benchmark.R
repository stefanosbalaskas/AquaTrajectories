.aqt_bundle_fixture <- function(directory,empty=FALSE) {
  prefix <- "demo"
  frames <- data.frame(
    session_id="S1",camera_id="TOP",
    frame_id=0:3,time_s=c(0,.043,.15,.204),
    width_px=100,height_px=80)
  outputs <- list(frames=paste0(prefix,".frames.csv"),
                  mot=paste0(prefix,".mot.txt"),
                  classes=paste0(prefix,".classes.csv"),
                  metadata=paste0(prefix,".run.json"))
  utils::write.csv(frames,file.path(directory,outputs$frames),
                   row.names=FALSE)
  if (empty) {
    file.create(file.path(directory,outputs$mot))
    classes <- data.frame(frame_id=numeric(),track_id=character(),
                          class_id=character())
  } else {
    mot <- data.frame(
      frame=c(1,2,4),track_id=c(7,7,7),
      left=c(10,11,50),top=c(20,20,20),
      width=rep(10,3),height=rep(8,3),
      confidence=c(.96,.93,.9),
      world1=-1,world2=-1,world3=-1)
    utils::write.table(
      mot,file.path(directory,outputs$mot),sep=",",
      row.names=FALSE,col.names=FALSE,quote=FALSE)
    classes <- data.frame(frame_id=c(0,1,3),
                          track_id=c("7","7","7"),
                          class_id=c("0","0","0"))
  }
  utils::write.csv(classes,file.path(directory,outputs$classes),
                   row.names=FALSE,quote=TRUE)
  sha <- lapply(outputs[c("frames","mot","classes")],
     function(name) digest::digest(file.path(directory,name),
                                   algo="sha256",file=TRUE))
  meta <- list(
    schema_version="1.1",
    session_id="S1",camera_id="TOP",
    time_source="decoded_video_frame_pts_from_same_buffer_as_model_input",
    time_s_relative_to_first_frame=TRUE,
    frame_origin_in_mot=1L,
    n_decoded_frames=4L,
    n_tracked_box_rows=if(empty)0L else 3L,
    outputs=outputs,
    output_sha256=sha,
    fish_identity_accuracy_certified=FALSE,
    underwater_3d_calibration_certified=FALSE)
  jsonlite::write_json(meta,file.path(directory,outputs$metadata),
                       pretty=TRUE,auto_unbox=TRUE)
  list(paths=file.path(directory,unlist(outputs)),
       outputs=outputs,meta=meta,frames=frames)
}

.aqt_bundle_truth <- function() {
  # The first two frames have an independently annotated fish. The
  # third frame is verified empty, and last has a predicted false positive.
  boxes <- data.frame(
    session_id="S1",camera_id="TOP",frame_id=c(0,1),
    class_id="0",xmin=c(10,11),ymin=20,
    xmax=c(20,21),ymax=28)
  tracks <- data.frame(
    session_id="S1",camera_id="TOP",frame_id=c(0,1),
    track_id="independent_fish_A",x=c(15,16),y=24,
    class_id="0")
  annotated <- data.frame(session_id="S1",camera_id="TOP",
                          frame_id=0:3)
  list(boxes=boxes,tracks=tracks,annotated=annotated)
}

test_that("verified video bundle reproduces frame PTS, labels and fish tracks", {
  dir <- tempfile("aqt-bundle-")
  dir.create(dir)
  on.exit(unlink(dir,recursive=TRUE),add=TRUE)
  .aqt_bundle_fixture(dir)
  x <- aqt_video_bundle_import(dir,"demo")
  expect_s3_class(x,"aqt_video_bundle")
  expect_equal(nrow(x$frames),4)
  expect_equal(x$frames$time_s,c(0,.043,.15,.204))
  expect_equal(nrow(x$tracks),3)
  expect_equal(x$tracks$frame_id,c(0,1,3))
  expect_equal(x$tracks$time_s,c(0,.043,.204))
  expect_true(all(x$tracks$class_id=="0"))
  expect_true(x$output_sha256_verified)
  expect_true(attr(x$tracks,"aqt_video_bundle_sha256_verified"))
  expect_false(x$source_video_sha256_verified)
  expect_false(x$source_weights_sha256_verified)
  expect_false(x$fish_identity_accuracy_certified)
  expect_false(x$hardware_exposure_synchronization_certified)
  expect_false(x$underwater_calibration_certified)
  expect_equal(x$support$n_missing_acquired_between,1)
})

test_that("zero-detection videos remain valid rather than fabricating fish", {
  dir <- tempfile("aqt-zero-")
  dir.create(dir)
  on.exit(unlink(dir,recursive=TRUE),add=TRUE)
  v <- .aqt_bundle_fixture(dir,empty=TRUE)
  tracks <- aqt_import_mot(
    file.path(dir,v$outputs$mot),
    aqt_frame_manifest(v$frames),
    session_id="S1",camera_id="TOP")
  expect_s3_class(tracks,"aqt_mot_tracks")
  expect_equal(nrow(tracks),0)
  x <- aqt_video_bundle_import(dir,"demo")
  expect_equal(nrow(x$frames),4)
  expect_equal(nrow(x$tracks),0)
  expect_equal(nrow(x$classes),0)
  expect_equal(nrow(x$support),0)
  expect_true(x$output_sha256_verified)
})

test_that("altered and mixed video output files fail SHA-256 verification", {
  dir <- tempfile("aqt-integrity-")
  dir.create(dir)
  on.exit(unlink(dir,recursive=TRUE),add=TRUE)
  x <- .aqt_bundle_fixture(dir)
  con <- file(file.path(dir,x$outputs$classes),"a")
  writeLines("4,7,1",con)
  close(con)
  expect_error(aqt_video_bundle_import(dir,"demo"),"SHA-256 mismatch")
  .aqt_bundle_fixture(dir)
  # Rehashing after reordering cannot bypass semantic row-key validation.
  sidepath <- file.path(dir,x$outputs$classes)
  sidecar <- utils::read.csv(sidepath,stringsAsFactors=FALSE)
  sidecar <- sidecar[c(3,2,1),,drop=FALSE]
  utils::write.csv(sidecar,sidepath,row.names=FALSE)
  metadata_path <- file.path(dir,x$outputs$metadata)
  meta <- jsonlite::fromJSON(metadata_path,simplifyVector=FALSE)
  meta$output_sha256$classes <- digest::digest(
    sidepath,algo="sha256",file=TRUE)
  jsonlite::write_json(meta,metadata_path,
                       pretty=TRUE,auto_unbox=TRUE)
  expect_error(aqt_video_bundle_import(dir,"demo"),
               "sidecar frame/track keys")
})

test_that("bundle metadata mismatch and missing artifacts fail closed", {
  dir <- tempfile("aqt-schema-")
  dir.create(dir)
  on.exit(unlink(dir,recursive=TRUE),add=TRUE)
  x <- .aqt_bundle_fixture(dir)
  path <- file.path(dir,x$outputs$metadata)
  meta <- jsonlite::fromJSON(path,simplifyVector=FALSE)
  meta$n_decoded_frames <- 6L
  jsonlite::write_json(meta,path,auto_unbox=TRUE)
  expect_error(aqt_video_bundle_import(dir,"demo"),
               "frame count")
  .aqt_bundle_fixture(dir)
  meta <- jsonlite::fromJSON(path,simplifyVector=FALSE)
  meta$outputs$mot <- "../other_video.mot.txt"
  jsonlite::write_json(meta,path,auto_unbox=TRUE)
  expect_error(aqt_video_bundle_import(dir,"demo"),
               "filenames do not match")
  .aqt_bundle_fixture(dir)
  unlink(file.path(dir,x$outputs$frames))
  expect_error(aqt_video_bundle_import(dir,"demo"),
               "Missing video bundle component")
  expect_error(aqt_video_bundle_import(dir,"../escape"),"safe")
})

test_that("only externally annotated video frames contribute to scores", {
  dir <- tempfile("aqt-eval-")
  dir.create(dir)
  on.exit(unlink(dir,recursive=TRUE),add=TRUE)
  .aqt_bundle_fixture(dir)
  bundle <- aqt_video_bundle_import(dir,"demo")
  truth <- .aqt_bundle_truth()
  b <- aqt_video_bundle_benchmark(
    bundle,truth$boxes,truth$tracks,truth$annotated,
    max_position_error_px=.1)
  expect_s3_class(b,"aqt_video_annotation_benchmark")
  expect_equal(b$n_evaluated_frames,4)
  expect_equal(b$annotated_frame_fraction,1)
  expect_equal(b$n_truth_boxes,2)
  expect_equal(b$n_truth_track_observations,2)
  expect_equal(b$n_predicted_tracks_in_video,3)
  all <- b$detection[b$detection$class_id=="ALL",,drop=FALSE]
  expect_equal(c(all$TP,all$FP,all$FN),c(2,1,0))
  expect_equal(all$F1,.8)
  expect_equal(b$tracking$IDTP,2)
  expect_equal(b$tracking$IDFP,1)
  expect_equal(b$tracking$IDFN,0)
  expect_equal(b$tracking$IDF1,.8)
  expect_false(b$independent_annotation_source_verified)
  expect_false(b$biological_identity_certified)
  expect_false(b$three_dimensional_position_accuracy_certified)
  short <- truth$annotated[truth$annotated$frame_id %in% 0:1,]
  only <- aqt_video_bundle_benchmark(
    bundle,truth$boxes,truth$tracks,short,
    max_position_error_px=.1)
  expect_equal(only$annotated_frame_fraction,.5)
  expect_equal(only$detection$F1[only$detection$class_id=="ALL"],1)
  expect_equal(only$tracking$IDF1,1)
})

test_that("annotation scope cannot cover impossible frames or unsupported truth", {
  dir <- tempfile("aqt-ref-")
  dir.create(dir)
  on.exit(unlink(dir,recursive=TRUE),add=TRUE)
  .aqt_bundle_fixture(dir)
  bundle <- aqt_video_bundle_import(dir,"demo")
  tr <- .aqt_bundle_truth()
  bad_frames <- tr$annotated
  bad_frames$frame_id[1] <- 200
  expect_error(aqt_video_bundle_benchmark(
    bundle,tr$boxes,tr$tracks,bad_frames),
    "absent from the decoded video")
  short <- tr$annotated[tr$annotated$frame_id==0,,drop=FALSE]
  expect_error(aqt_video_bundle_benchmark(
    bundle,tr$boxes,tr$tracks,short),
    "outside the independent annotation")
  repeated <- rbind(tr$annotated,tr$annotated[1,,drop=FALSE])
  expect_error(aqt_video_bundle_benchmark(
    bundle,tr$boxes,tr$tracks,repeated),"Duplicate evaluated frame")
  expect_error(aqt_video_bundle_benchmark(
    bundle,tr$boxes,tr$tracks,
    transform(tr$annotated,frame_id=frame_id+.5)),
    "nonnegative integers")
})
