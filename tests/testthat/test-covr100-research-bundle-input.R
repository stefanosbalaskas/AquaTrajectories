# Original Research Bundle v1 byte integrity is distinct from independent
# authentication of video source, tracking IDs or acquisition time.
.cov100_research_bundle <- function(root,time_status="source_pts") {
 dir.create(root,recursive=TRUE,showWarnings=FALSE)
 frame <- data.frame(session_id="S",camera_id="TOP",frame_id=0:2,
    time_s=if(time_status=="unknown")rep(NA_real_,3) else c(0,.1,.2),
    width_px=64,height_px=48)
 obs <- data.frame(session_id="S",camera_id="TOP",track_id=rep("0007",3),
    frame_id=0:2,time_s=frame$time_s,x=10:12,y=rep(20,3),
    observed=TRUE,quality_flag=rep("unreviewed",3),
    position_definition=rep("source_xy",3),
    bbox_left=rep(NA_real_,3),bbox_top=rep(NA_real_,3),
    bbox_width=rep(NA_real_,3),bbox_height=rep(NA_real_,3),
    detection_confidence=rep(NA_real_,3),
    identity_probability=rep(NA_real_,3),source_row=1:3)
 utils::write.csv(frame,file.path(root,"frames.csv"),row.names=FALSE,na="")
 utils::write.csv(obs,file.path(root,"observations.csv"),row.names=FALSE,na="")
 meta <- list(schema_version="1.0.0",
   coordinate_units="px",coordinate_system="image",
   time_status=time_status,session_id="S",camera_id="TOP",
   fish_identity_accuracy_certified=FALSE,
   cross_camera_identity_certified=FALSE,
   underwater_calibration_certified=FALSE,
   n_frames=3L,n_observations=3L,
   tracking_kind="source_or_manual_track_ids",
   output_sha256=list(
     "frames.csv"=unname(digest::digest(file.path(root,"frames.csv"),
                         file=TRUE,algo="sha256")),
     "observations.csv"=unname(digest::digest(file.path(root,"observations.csv"),
                         file=TRUE,algo="sha256"))))
 jsonlite::write_json(meta,file.path(root,"manifest.json"),
      pretty=TRUE,auto_unbox=TRUE,null="null")
 list(frames=frame,observations=obs,meta=meta)
}
test_that("Research Bundle v1 and acquisition QC accept exact synthetic source bytes",{
 root <- tempfile("cov100_bundle_")
 on.exit(unlink(root,recursive=TRUE,force=TRUE),add=TRUE)
 x <- .cov100_research_bundle(root)
 bundle <- aqt_research_bundle_import(root)
 expect_s3_class(bundle,"aqt_research_bundle")
 expect_true(bundle$output_sha256_verified)
 expect_equal(nrow(bundle$tracks),3L)
 expect_false(bundle$clock_independently_verified)
 expect_equal(bundle$metadata$time_status,"source_pts")
 raw <- serialize(bundle$observations,NULL)
 qc <- aqt_trajectory_qc(bundle,max_gap_s=.11)
 expect_equal(qc$provenance$source_type,"research_bundle_v1")
 expect_equal(qc$time_provenance,"source_pts")
 expect_equal(qc$raw_sha256,digest::digest(qc$raw,
                     algo="sha256",serialize=TRUE))
 expect_identical(serialize(bundle$observations,NULL),raw)
 expect_equal(sum(qc$row_audit$automatically_eligible),3)
 expect_error(aqt_trajectory_qc(bundle,frames=x$frames),
              "Bundle already contains authenticated frames")
})
test_that("Research Bundle v1 unknown timing stays unavailable rather than invented",{
 root <- tempfile("cov100_bundle_unknown_")
 on.exit(unlink(root,recursive=TRUE,force=TRUE),add=TRUE)
 .cov100_research_bundle(root,time_status="unknown")
 bundle <- aqt_research_bundle_import(root)
 expect_null(bundle$tracks)
 expect_equal(bundle$metadata$time_status,"unknown")
 qc <- aqt_trajectory_qc(bundle,max_gap_s=.11)
 expect_equal(qc$time_provenance,"unknown")
 review <- aqt_qc_review(qc)
 result <- aqt_research_analyze(review,profiles=c("movement","uncertainty"))
 expect_true(all(result$diagnostics$status[
    result$diagnostics$profile %in% c("movement","uncertainty")]=="blocked"))
})
test_that("Research Bundle import detects changed source bytes before numerical analysis", {
 root <- tempfile("cov100_bundle_corrupt_")
 on.exit(unlink(root,recursive=TRUE,force=TRUE),add=TRUE)
 .cov100_research_bundle(root)
 cat("unverified extra source",file=file.path(root,"observations.csv"),
     append=TRUE)
 expect_error(aqt_research_bundle_import(root),
             "Research bundle integrity mismatch")
})


test_that("unknown camera time forbids experimental tank mapping before inference",{
 root <- tempfile("cov100_bundle_no_clock_design_")
 on.exit(unlink(root,recursive=TRUE,force=TRUE),add=TRUE)
 .cov100_research_bundle(root,time_status="unknown")
 bundle <- aqt_research_bundle_import(root)
 review <- aqt_qc_review(aqt_trajectory_qc(bundle,max_gap_s=.11))
 design <- data.frame(session_id="S",camera_id="TOP",
                      tank_id="T",treatment="control")
 expect_error(aqt_research_analyze(review,profiles="experimental",
                  design=design),
              "Design analysis requires time-qualified reviewed trajectories")
})
