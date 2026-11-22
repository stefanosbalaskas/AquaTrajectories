# A fixture resembling four runner outputs, with exact file hashes. The
# source video/model are not present; confidence, identity and real-world
# provenance remain explicitly uncertified.
.cov100_zero_video_bundle <- function(parent) {
 prefix <- "synthetic_no_fish"
 files <- list(frames=paste0(prefix,".frames.csv"),
      mot=paste0(prefix,".mot.txt"),
      classes=paste0(prefix,".classes.csv"),
      metadata=paste0(prefix,".run.json"))
 frames <- data.frame(session_id="S",camera_id="TOP",frame_id=0:2,
      time_s=c(0,.1,.2),width_px=64,height_px=48)
 utils::write.csv(frames,file.path(parent,files$frames),row.names=FALSE)
 file.create(file.path(parent,files$mot))
 cls <- data.frame(frame_id=numeric(0),track_id=character(0),
      class_id=character(0))
 utils::write.csv(cls,file.path(parent,files$classes),row.names=FALSE)
 hashes <- list()
 for(nm in c("frames","mot","classes"))
   hashes[[nm]] <- unname(digest::digest(file.path(parent,files[[nm]]),
                            file=TRUE,algo="sha256"))
 metadata <- list(schema_version="1.1",
    time_source="decoded_video_frame_pts_from_same_buffer_as_model_input",
    time_s_relative_to_first_frame=TRUE,
    frame_origin_in_mot=1,
    n_decoded_frames=3,n_tracked_box_rows=0,
    session_id="S",camera_id="TOP",
    outputs=files,output_sha256=hashes)
 jsonlite::write_json(metadata,file.path(parent,files$metadata),
       pretty=TRUE,auto_unbox=TRUE)
 list(prefix=prefix,frames=frames,files=files,metadata=metadata)
}
test_that("verified video bundle supports a genuine zero-detection source recording", {
 dir <- tempfile("cov100_video_");dir.create(dir)
 on.exit(unlink(dir,recursive=TRUE,force=TRUE),add=TRUE)
 z <- .cov100_zero_video_bundle(dir)
 f <- function(...) aqt_video_bundle_import(dir,z$prefix)
 imported <- f()
 expect_s3_class(imported,"aqt_video_bundle")
 expect_equal(nrow(imported$frames),3)
 expect_equal(nrow(imported$tracks),0)
 expect_equal(nrow(imported$classes),0)
 expect_true(imported$output_sha256_verified)
 expect_false(imported$source_video_sha256_verified)
 expect_false(imported$fish_identity_accuracy_certified)
 expect_false(imported$hardware_exposure_synchronization_certified)
 expect_error(aqt_video_bundle_import(dir,"../incorrect"),"safe video bundle")
 expect_error(aqt_video_bundle_import(tempfile(),z$prefix),
              "existing video bundle directory")
 # An independent fully annotated zero-fish frame is meaningful, not NA recall.
 ev <- data.frame(session_id="S",camera_id="TOP",frame_id=0,
                  annotation_status="fully_annotated")
 truth_box <- data.frame(session_id=character(),camera_id=character(),
       frame_id=numeric(),class_id=character(),xmin=numeric(),
       ymin=numeric(),xmax=numeric(),ymax=numeric())
 truth_track <- data.frame(session_id=character(),camera_id=character(),
       frame_id=numeric(),track_id=character(),x=numeric(),y=numeric(),
       class_id=character())
 result <- aqt_video_bundle_benchmark(imported,truth_box,truth_track,ev)
 expect_s3_class(result,"aqt_video_annotation_benchmark")
 expect_equal(result$n_evaluated_frames,1L)
 expect_equal(result$n_truth_boxes,0L)
 expect_equal(result$n_predicted_tracks_in_video,0L)
 expect_equal(result$annotated_frame_fraction,1/3,tolerance=1e-12)
 expect_false(result$independent_annotation_source_verified)
 expect_false(result$biological_identity_certified)
 wrong <- ev;wrong$frame_id <- 100
 expect_error(aqt_video_bundle_benchmark(imported,truth_box,truth_track,wrong),
              "absent from the decoded")
 not_reviewed <- ev;not_reviewed$annotation_status <- "planned_not_annotated"
 expect_error(aqt_video_bundle_benchmark(imported,truth_box,truth_track,
              not_reviewed),"must be fully_annotated")
 expect_error(aqt_video_bundle_benchmark(list(),truth_box,truth_track,ev),
              "SHA-256-verified")
})
test_that("video bundle import rejects missing files, schema drift, and mixed-run tampering",{
 dir <- tempfile("cov100_video_");dir.create(dir)
 on.exit(unlink(dir,recursive=TRUE,force=TRUE),add=TRUE)
 z <- .cov100_zero_video_bundle(dir)
 meta_path <- file.path(dir,z$files$metadata)
 frames_path <- file.path(dir,z$files$frames)
 classes_path <- file.path(dir,z$files$classes)
 original <- readLines(meta_path,warn=FALSE)
 writeLines("{not valid JSON}",meta_path)
 expect_error(aqt_video_bundle_import(dir,z$prefix),
              "Malformed video run metadata JSON")
 writeLines(original,meta_path)
 bad <- z$metadata;bad$schema_version <- "0.0"
 jsonlite::write_json(bad,meta_path,pretty=TRUE,auto_unbox=TRUE)
 expect_error(aqt_video_bundle_import(dir,z$prefix),
              "Incompatible or incomplete")
 bad <- z$metadata;bad$outputs$mot <- "other.mot"
 jsonlite::write_json(bad,meta_path,pretty=TRUE,auto_unbox=TRUE)
 expect_error(aqt_video_bundle_import(dir,z$prefix),
              "filenames do not match")
 jsonlite::write_json(z$metadata,meta_path,pretty=TRUE,auto_unbox=TRUE)
 write("surreptitious extra frame",file=frames_path,append=TRUE)
 expect_error(aqt_video_bundle_import(dir,z$prefix),
              "SHA-256 mismatch")
 .cov100_zero_video_bundle(dir)
 bad <- z$metadata;bad$n_decoded_frames <- 4
 jsonlite::write_json(bad,meta_path,pretty=TRUE,auto_unbox=TRUE)
 expect_error(aqt_video_bundle_import(dir,z$prefix),
              "frame count, scope")
 .cov100_zero_video_bundle(dir)
 bad <- z$metadata;bad$n_tracked_box_rows <- -1
 jsonlite::write_json(bad,meta_path,pretty=TRUE,auto_unbox=TRUE)
 expect_error(aqt_video_bundle_import(dir,z$prefix),
              "Invalid decoded frame")
 .cov100_zero_video_bundle(dir)
 unlink(classes_path)
 expect_error(aqt_video_bundle_import(dir,z$prefix),
              "all four outputs are required")
})


test_that("verified runner files reject malformed independent metadata, frame, and class schemas",{
  dir <- tempfile("cov100_vid_negative_")
  dir.create(dir)
  on.exit(unlink(dir,recursive=TRUE,force=TRUE),add=TRUE)
  remake <- function() .cov100_zero_video_bundle(dir)
  save_meta <- function(x,source=NULL) {
    if(!is.null(source))
      x$output_sha256[[source]] <- unname(digest::digest(
         file.path(dir,x$outputs[[source]]),file=TRUE,algo="sha256"))
    jsonlite::write_json(x,file.path(dir,x$outputs$metadata),
                         pretty=TRUE,auto_unbox=TRUE)
  }
  z <- remake()
  bad <- z$metadata;bad$output_sha256$frames <- NULL
  save_meta(bad)
  expect_error(aqt_video_bundle_import(dir,z$prefix),
               "Missing or malformed SHA-256")
  z <- remake()
  bad <- z$metadata;bad$session_id <- ""
  save_meta(bad)
  expect_error(aqt_video_bundle_import(dir,z$prefix),
               "recording scope must be complete")
  z <- remake()
  f <- z$frames
  names(f)[1] <- "unregistered_field"
  utils::write.csv(f,file.path(dir,z$files$frames),row.names=FALSE)
  save_meta(z$metadata,"frames")
  expect_error(aqt_video_bundle_import(dir,z$prefix),
               "Unexpected video frame manifest columns")
  z <- remake()
  side <- data.frame(frame_id=numeric(0),track_id=character(0),
                    not_a_class=character(0))
  utils::write.csv(side,file.path(dir,z$files$classes),row.names=FALSE)
  save_meta(z$metadata,"classes")
  expect_error(aqt_video_bundle_import(dir,z$prefix),
               "Unexpected video class sidecar columns")
  z <- remake()
  bad <- z$metadata;bad$n_tracked_box_rows <- 1L
  save_meta(bad)
  expect_error(aqt_video_bundle_import(dir,z$prefix),
               "MOT, class sidecar and run metadata")
  z <- remake()
  bad <- z$metadata;bad$camera_id <- "WRONG"
  save_meta(bad)
  expect_error(aqt_video_bundle_import(dir,z$prefix),
               "Runner frame count, scope")
});
