# Non-destructive source-frame QC respects pixel-space coordinates and
# empty-identity records. None of these tests certify a physical fish ID.
.cov100_acq_frames <- function() data.frame(
 session_id="S",camera_id="C",frame_id=0:4,
 time_s=(0:4)*.1,width_px=100,height_px=80)
.cov100_acq_rows <- function() data.frame(
 session_id="S",camera_id="C",track_id="001",
 frame_id=0:4,time_s=(0:4)*.1,
 x=10:14,y=rep(20,5),observed=TRUE,
 detection_confidence=rep(.9,5))
test_that("acquisition QC rejects physical trajectories before pixel-screening", {
 f <- .cov100_acq_frames()
 d <- .cov100_acq_rows()
 tr <- aqt_tracks(d,units="cm",coordinate_system="tank")
 expect_error(aqt_trajectory_qc(tr,f),
              "requires image-space coordinates")
 bad <- d;bad$z <- rep(1,5)
 expect_error(aqt_trajectory_qc(bad,f),"not physical XYZ")
 no_conf <- d;no_conf$detection_confidence <- NULL
 expect_error(aqt_trajectory_qc(no_conf,f,
                 min_detection_confidence=.3),
              "requires source detection_confidence")
 expect_error(aqt_trajectory_qc(d,f,min_detection_confidence=1.1),
              "within")
 expect_error(aqt_trajectory_qc(d,f,min_detection_confidence=-.1),
              "within")
 fake <- structure(list(directory=tempdir()),
                   class="aqt_research_bundle")
 expect_error(aqt_trajectory_qc(fake,f),
              "Bundle already contains authenticated frames")
})
test_that("acquisition QC produces a valid empty source-track coverage ledger",{
 frames <- .cov100_acq_frames()
 raw <- .cov100_acq_rows()[FALSE,,drop=FALSE]
 q <- aqt_trajectory_qc(raw,frames,max_gap_s=.2)
 expect_s3_class(q,"aqt_trajectory_qc")
 expect_equal(nrow(q$raw),0L)
 expect_equal(nrow(q$per_track_coverage),0L)
 expect_equal(nrow(q$camera_coverage),1L)
 expect_equal(q$camera_coverage$n_frames_with_eligible_track,0L)
 review <- aqt_qc_review(q)
 expect_equal(review$n_original,0L)
 expect_equal(review$n_review_eligible,0L)
 expect_false(review$independent_human_review_certified)
})
test_that("review and reporting preserve original tracker rows under nonuniform source PTS",{
 frames <- .cov100_acq_frames()
 frames$time_s <- c(0,.1,.3,.4,.8)
 raw <- .cov100_acq_rows()
 raw$time_s <- frames$time_s
 source <- serialize(raw,NULL)
 qc <- aqt_trajectory_qc(raw,frames,max_gap_s=.15,
           max_jump_px=1.5,min_detection_confidence=.8)
 expect_identical(serialize(raw,NULL),source)
 expect_true(all(qc$flags$automatically_eligible))
 expect_true(sum(qc$flags$large_gap)>=2L)
 review <- aqt_qc_review(qc)
 derived <- aqt_qc_derived(review)
 expect_true(is.data.frame(derived$kinematics))
 parent <- tempfile("cov100_acquisition_")
 dir.create(parent)
 on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
 dir <- file.path(parent,"QC")
 expect_invisible(aqt_qc_report(review,derived,directory=dir))
 expect_true(file.exists(file.path(dir,"RAW_OBSERVATIONS.csv")))
 expect_true(file.exists(file.path(dir,"QC_REPORT_MANIFEST.json")))
 expect_true(file.exists(file.path(dir,"DERIVED_PATH_SUMMARY.csv")))
 manifest <- jsonlite::fromJSON(file.path(dir,"QC_REPORT_MANIFEST.json"),
                                simplifyVector=FALSE)
 expect_identical(manifest$original_source_sha256,
                  digest::digest(qc$raw,algo="sha256",serialize=TRUE))
 expect_false(manifest$independent_human_review_certified)
 expect_error(aqt_qc_report(review,derived,directory=dir),
              "destination must be new")
})
