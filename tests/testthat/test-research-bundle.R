# Fully synthetic package-level regression: no Python, videos, real fish, weights.
make_test_research_bundle <- function(root,clock="source_pts") {
  dir.create(root)
  tt <- if(identical(clock,"unknown")) c(NA_real_,NA_real_) else c(0,.05)
  frames <- data.frame(session_id=c("S","S"),camera_id=c("TOP","TOP"),
                       frame_id=0:1,time_s=tt,width_px=c(100L,100L),
                       height_px=c(80L,80L))
  obs <- data.frame(session_id=c("S","S"),camera_id=c("TOP","TOP"),
    track_id=c("0007","0007"),frame_id=0:1,time_s=tt,
    x=c(15,16),y=c(25,25),observed=c(TRUE,TRUE),
    quality_flag=c("unreviewed","unreviewed"),
    position_definition=c("bbox_center","bbox_center"),
    bbox_left=c(10,11),bbox_top=c(20,20),
    bbox_width=c(10,10),bbox_height=c(10,10),
    detection_confidence=c(.8,.9),identity_probability=c(NA_real_,NA_real_),
    source_row=1:2,stringsAsFactors=FALSE)
  utils::write.csv(frames,file.path(root,"frames.csv"),row.names=FALSE,na="")
  utils::write.csv(obs,file.path(root,"observations.csv"),row.names=FALSE,na="")
  meta <- list(schema_version="1.0.0",session_id="S",camera_id="TOP",
    tracking_kind="mot_bytetrack",time_status=clock,
    coordinate_units="px",coordinate_system="image",
    n_frames=2L,n_observations=2L,
    fish_identity_accuracy_certified=FALSE,
    cross_camera_identity_certified=FALSE,
    underwater_calibration_certified=FALSE,
    output_sha256=list(
      "frames.csv"=unname(digest::digest(file.path(root,"frames.csv"),
                                        file=TRUE,algo="sha256")),
      "observations.csv"=unname(digest::digest(file.path(root,"observations.csv"),
                                              file=TRUE,algo="sha256"))))
  jsonlite::write_json(meta,file.path(root,"manifest.json"),
                       auto_unbox=TRUE,pretty=TRUE)
}

test_that("research bundle preserves identifiers, time, coordinates and source bytes", {
  root <- tempfile("aqt-research-known-")
  make_test_research_bundle(root)
  on.exit(unlink(root,recursive=TRUE),add=TRUE)
  z <- aqt_research_bundle_import(root)
  expect_s3_class(z,"aqt_research_bundle")
  expect_true(z$output_sha256_verified)
  expect_s3_class(z$tracks,"aqt_tracks")
  expect_identical(as.character(z$tracks$track_id),c("0007","0007"))
  expect_equal(z$tracks$x,c(15,16))
  expect_equal(z$tracks$time_s,c(0,.05))
  expect_false(z$biological_identity_certified)
  expect_false(z$clock_independently_verified)
  target <- tempfile("aqt-research-roundtrip-")
  on.exit(unlink(target,recursive=TRUE),add=TRUE)
  aqt_research_bundle_export(z,target)
  for (file in c("frames.csv","observations.csv","manifest.json"))
    expect_identical(digest::digest(file.path(root,file),file=TRUE,algo="sha256"),
                     digest::digest(file.path(target,file),file=TRUE,algo="sha256"))
  again <- aqt_research_bundle_import(target)
  expect_identical(z$metadata,again$metadata)
  expect_identical(z$observations,again$observations)
  expect_error(aqt_research_bundle_export(z,target),"destination")
})

test_that("unknown clocks remain inspectable but cannot enter time-based models", {
  root <- tempfile("aqt-research-no-clock-")
  make_test_research_bundle(root,"unknown")
  on.exit(unlink(root,recursive=TRUE),add=TRUE)
  z <- aqt_research_bundle_import(root)
  expect_null(z$tracks)
  expect_true(all(is.na(z$frames$time_s)))
  expect_true(all(is.na(z$observations$time_s)))
  expect_error(aqt_kinematics(z$tracks),"Expected")
})

test_that("research importer refuses modified output bytes", {
  root <- tempfile("aqt-research-tamper-")
  make_test_research_bundle(root)
  on.exit(unlink(root,recursive=TRUE),add=TRUE)
  cat("\n",file=file.path(root,"observations.csv"),append=TRUE)
  expect_error(aqt_research_bundle_import(root),"integrity mismatch")
})
