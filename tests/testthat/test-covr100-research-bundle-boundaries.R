# Synthetic Research Bundle v1 schema and provenance mutations.
# Every malformed source is independently byte-sealed before import, so the
# failure being tested is validation, NOT an unrelated SHA-256 mismatch.

.cov100_bundle <- function() {
  root <- tempfile("cov100_bundle_")
  dir.create(root)
  frames <- data.frame(session_id=c("S","S"),camera_id=c("TOP","TOP"),
      frame_id=0:1,time_s=c(0,.05),width_px=c(100,100),
      height_px=c(80,80))
  obs <- data.frame(session_id=c("S","S"),camera_id=c("TOP","TOP"),
      track_id=c("0007","0007"),frame_id=0:1,time_s=c(0,.05),
      x=c(15,16),y=c(25,26),observed=c(TRUE,TRUE),
      quality_flag=c("unreviewed","unreviewed"),
      position_definition=c("bbox_center","bbox_center"),
      bbox_left=c(10,11),bbox_top=c(20,21),bbox_width=c(10,10),
      bbox_height=c(10,10),detection_confidence=c(.8,.9),
      identity_probability=c(NA_real_,NA_real_),source_row=1:2)
  meta <- list(schema_version="1.0.0",session_id="S",camera_id="TOP",
      tracking_kind="mot_bytetrack",time_status="source_pts",
      coordinate_units="px",coordinate_system="image",
      n_frames=2L,n_observations=2L,
      fish_identity_accuracy_certified=FALSE,
      cross_camera_identity_certified=FALSE,
      underwater_calibration_certified=FALSE,
      output_sha256=list("frames.csv"="","observations.csv"=""))
  list(root=root,frames=frames,obs=obs,meta=meta)
}

.cov100_bundle_seal <- function(b) {
  utils::write.csv(b$frames,file.path(b$root,"frames.csv"),
                   row.names=FALSE,na="")
  utils::write.csv(b$obs,file.path(b$root,"observations.csv"),
                   row.names=FALSE,na="")
  for(name in c("frames.csv","observations.csv"))
    b$meta$output_sha256[[name]] <- unname(digest::digest(
      file.path(b$root,name),file=TRUE,algo="sha256"))
  jsonlite::write_json(b$meta,file.path(b$root,"manifest.json"),
                       auto_unbox=TRUE,pretty=TRUE)
  b
}

.cov100_bundle_reject <- function(change,pattern) {
  b <- .cov100_bundle()
  on.exit(unlink(b$root,recursive=TRUE,force=TRUE),add=TRUE)
  b <- change(b)
  b <- .cov100_bundle_seal(b)
  testthat::expect_error(aqt_research_bundle_import(b$root),pattern)
}

test_that("research bundles require actual files and truthful metadata", {
  expect_error(aqt_research_bundle_import(tempfile()),"Existing")
  empty <- tempfile("cov100_empty_bundle_")
  dir.create(empty)
  on.exit(unlink(empty,recursive=TRUE,force=TRUE),add=TRUE)
  expect_error(aqt_research_bundle_import(empty),"Incomplete")
  .cov100_bundle_reject(function(b){
    b$meta$schema_version <- "2.0.0";b
  },"Unsupported")
  .cov100_bundle_reject(function(b){
    b$meta$coordinate_units <- "cm";b
  },"Unsupported")
  .cov100_bundle_reject(function(b){
    b$meta$fish_identity_accuracy_certified <- TRUE;b
  },"Unsupported")
  .cov100_bundle_reject(function(b){
    b$meta$n_frames <- 4L;b
  },"Incorrect bundle row counts")
  .cov100_bundle_reject(function(b){
    names(b$obs)[names(b$obs)=="source_row"] <- "unverified_source";b
  },"Unexpected Research Bundle")
  .cov100_bundle_reject(function(b){
    b$frames$session_id[1] <- "WRONG";b
  },"scope mismatch")
  .cov100_bundle_reject(function(b){
    b$frames$width_px[1] <- -1;b
  },"Invalid source-frame")
  .cov100_bundle_reject(function(b){
    b$frames$frame_id[2] <- 0;b
  },"Invalid source-frame")
  .cov100_bundle_reject(function(b){
    b$frames$time_s[2] <- NA_real_;b
  },"Frame timing")
  .cov100_bundle_reject(function(b){
    b$meta$time_status <- "unknown";b
  },"Frame timing")
})

test_that("research bundle refuses invalid coordinates, clocks, bounding boxes and identities", {
  .cov100_bundle_reject(function(b){
    b$obs$x[1] <- "not-a-number";b
  },"Non-numeric observation")
  .cov100_bundle_reject(function(b){
    b$obs$y[1] <- Inf;b
  },"Nonfinite observation")
  .cov100_bundle_reject(function(b){
    b$obs$frame_id[1] <- 99;b
  },"absent source frame")
  .cov100_bundle_reject(function(b){
    b$obs$source_row[1] <- -1;b
  },"invalid track identity")
  .cov100_bundle_reject(function(b){
    b$obs$track_id[1] <- "";b
  },"invalid track identity")
  .cov100_bundle_reject(function(b){
    b$obs$time_s[1] <- .15;b
  },"does not match recorded frame time")
  .cov100_bundle_reject(function(b){
    b$obs$observed[1] <- FALSE;b
  },"Invalid observed flags")
  .cov100_bundle_reject(function(b){
    b$obs$quality_flag[1] <- "verified_fish";b
  },"Invalid observed flags")
  .cov100_bundle_reject(function(b){
    b$obs$x[1] <- 800;b
  },"outside image frame")
  .cov100_bundle_reject(function(b){
    b$obs$bbox_width[1] <- NA_real_;b
  },"Incomplete bounding box")
  .cov100_bundle_reject(function(b){
    b$obs$bbox_width[1] <- 500;b
  },"Invalid bounding box")
  .cov100_bundle_reject(function(b){
    b$obs$detection_confidence[1] <- 1.5;b
  },"Confidence/probability")
  .cov100_bundle_reject(function(b){
    b$obs$identity_probability[1] <- -.1;b
  },"Confidence/probability")
})

test_that("unknown frame clock cannot conceal observed seconds", {
  b <- .cov100_bundle()
  on.exit(unlink(b$root,recursive=TRUE,force=TRUE),add=TRUE)
  b$meta$time_status <- "unknown"
  b$frames$time_s <- NA_real_
  # Retaining recorded observation seconds under unknown time is invalid.
  b <- .cov100_bundle_seal(b)
  expect_error(aqt_research_bundle_import(b$root),"invented observation seconds")
})

test_that("byte-preserving export refuses invalid and changed provenance", {
  expect_error(aqt_research_bundle_export(list(),tempfile()),"Expected a validated")
  b <- .cov100_bundle()
  on.exit(unlink(b$root,recursive=TRUE,force=TRUE),add=TRUE)
  b <- .cov100_bundle_seal(b)
  valid <- aqt_research_bundle_import(b$root)
  invalid <- valid
  invalid$metadata$output_sha256[["frames.csv"]] <- paste(rep("f",64),collapse="")
  expect_error(aqt_research_bundle_export(invalid,tempfile("out_")),
               "provenance changed")
})

test_that("byte-preserving bundle exporter rejects failed copy and atomic publication", {
  b <- .cov100_bundle()
  on.exit(unlink(b$root,recursive=TRUE,force=TRUE),add=TRUE)
  b <- .cov100_bundle_seal(b)
  verified <- aqt_research_bundle_import(b$root)
  parent <- tempfile("cov100_bundle_fs_");base::dir.create(parent)
  on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
  copyout <- file.path(parent,"copy-failed")
  testthat::with_mocked_bindings({
    expect_error(aqt_research_bundle_export(verified,copyout),
                 "Could not copy complete research bundle")
  },file.copy=function(...) FALSE,.package="aquaTrajectories")
  expect_false(dir.exists(copyout))
  moveout <- file.path(parent,"rename-failed")
  testthat::with_mocked_bindings({
    expect_error(aqt_research_bundle_export(verified,moveout),
                 "Could not commit byte-preserved research bundle")
  },file.rename=function(...) FALSE,.package="aquaTrajectories")
  expect_false(dir.exists(moveout))
  expect_true(verified$output_sha256_verified)
})
