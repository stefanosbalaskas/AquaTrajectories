# Synthetic, source-preserving QC regression; no private fish data.

qc_fixture <- function(unknown_time=FALSE) {
  ff <- data.frame(session_id="S1",camera_id="TOP",frame_id=0:5,
    time_s=if(unknown_time) rep(NA_real_,6) else seq(0,.5,by=.1),
    width_px=rep(100,6),height_px=rep(80,6))
  obs <- data.frame(session_id="S1",camera_id="TOP",
    track_id=c(rep("0007",6),"B","B","C","D"),
    frame_id=c(0:5,1,1,0,0),
    time_s=if(unknown_time) rep(NA_real_,10) else
      c(seq(0,.5,by=.1),.1,.1,0,0),
    x=c(0,1,NA,3,50,51,2,2,-1,10),
    y=c(0,0,NA,0,0,0,2,2,2,10),
    observed=c(TRUE,TRUE,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE,TRUE),
    detection_confidence=c(rep(.9,6),.8,.7,.8,.2),
    stringsAsFactors=FALSE)
  list(obs=obs,frames=ff)
}

test_that("raw, reviewed and derived states remain distinct, with row accountability", {
  f <- qc_fixture()
  original <- f$obs
  a <- aqt_trajectory_qc(f$obs,f$frames,
      max_gap_s=.15,max_jump_px=10,min_detection_confidence=.5)
  expect_s3_class(a,"aqt_trajectory_qc")
  expect_identical(a$raw,original)
  expect_equal(nrow(a$row_audit),nrow(original))
  expect_true(all(a$row_audit$flag_duplicate_identity[c(7,8)]))
  expect_true(a$row_audit$flag_out_of_bounds[9])
  expect_true(a$row_audit$flag_missing_position[3])
  expect_true(a$row_audit$flag_jump[5])
  expect_true(a$row_audit$flag_low_confidence[10])
  expect_equal(a$camera_coverage$n_acquisition_frames,6)
  expect_equal(a$per_track_coverage$n_frames_in_observed_span[
    a$per_track_coverage$track_id=="0007"],6)
  reviewed <- aqt_qc_review(a)
  expect_s3_class(reviewed,"aqt_qc_review")
  expect_false(reviewed$tracks$observed[
    reviewed$tracks$raw_row==5L])
  expect_false(reviewed$tracks$observed[
    reviewed$tracks$raw_row==3L])
  expect_true(all(!c(7L,8L,9L) %in% reviewed$tracks$raw_row))
  expect_identical(a$raw,original)
  derived <- aqt_qc_derive(reviewed,max_gap_s=.15)
  expect_s3_class(derived,"aqt_qc_derived")
  expect_equal(derived$summary$n_source_rows,10)
  expect_equal(derived$summary$n_duplicate_identity_rows,2)
  expect_equal(derived$summary$n_missing_positions,1)
  expect_equal(derived$summary$n_review_eligible,4) # A0,A1,A3,A5
  expect_equal(derived$summary$n_usable_movements,1) # A0 -> A1
  expect_equal(derived$path_summary$path_length[
    derived$path_summary$track_id=="0007"],1)
  expect_true(all(derived$kinematics$raw_row %in% c(1:6,10)))
  expect_false(derived$fish_identity_accuracy_certified)
})

test_that("missing acquisition frames are not treated as valid movement", {
  f <- qc_fixture()
  f$obs <- f$obs[c(1,4),,drop=FALSE]
  qc <- aqt_trajectory_qc(f$obs,f$frames,max_gap_s=.6)
  rev <- aqt_qc_review(qc)
  d <- aqt_qc_derive(rev,max_gap_s=.6)
  expect_true(qc$row_audit$flag_gap_boundary[2])
  expect_equal(d$summary$n_usable_movements,0)
  expect_equal(d$path_summary$path_length,0)
  expect_equal(d$path_summary$valid_steps,0)
})

test_that("unknown frame timestamps block time-derived analyses without inventing FPS", {
  f <- qc_fixture(TRUE)
  qc <- aqt_trajectory_qc(f$obs,f$frames,max_gap_s=.2)
  rev <- aqt_qc_review(qc)
  expect_null(rev$tracks)
  expect_match(rev$analysis_blocked,"clock|timestamps")
  expect_error(aqt_qc_derive(rev),"without source timestamps")
  expect_error(aqt_trajectory_qc(f$obs,f$frames,max_speed=2),
               "requires real source timestamps")
})

test_that("manual decisions can exclude, but cannot accept corrupt data", {
  f <- qc_fixture()
  q <- aqt_trajectory_qc(f$obs,f$frames,max_jump_px=10)
  reject <- data.frame(raw_row=2,decision="exclude",reason="manually rejected blur")
  r <- aqt_qc_review(q,reject)
  expect_identical(r$row_audit$manual_decision[2],"exclude")
  expect_false(r$row_audit$review_eligible[2])
  accept <- data.frame(raw_row=5,decision="accept",reason="video reviewed real jump")
  r2 <- aqt_qc_review(q,accept)
  expect_true(r2$row_audit$review_eligible[5])
  expect_equal(r2$n_manual_decisions,1)
  impossible <- data.frame(raw_row=9,decision="accept",reason="override")
  expect_error(aqt_qc_review(q,impossible),"cannot accept")
  duplicated <- data.frame(raw_row=7,decision="accept",reason="override")
  expect_error(aqt_qc_review(q,duplicated),"cannot accept")
})

test_that("expected roster distinguishes detection opportunities from tracking coverage", {
  f <- qc_fixture()
  e <- data.frame(session_id=c("S1","S1"),camera_id="TOP",
                  track_id=c("0007","NEVER_PRESENT"))
  q <- aqt_trajectory_qc(f$obs,f$frames,max_jump_px=10,
                          expected_tracks=e)
  expect_true(q$camera_coverage$expected_fish_count_known)
  expect_equal(q$expected_coverage$eligible_fraction[2],0)
  expect_equal(q$expected_coverage$n_acquisition_frames[2],6)
  expect_false(q$complete_detection_recall_certified)
})

test_that("manual annotation metrics only score explicitly annotated frames", {
  f <- qc_fixture()
  q <- aqt_trajectory_qc(f$obs,f$frames,
    truth=data.frame(session_id="S1",camera_id="TOP",
      frame_id=c(0,1),track_id="TRUEFISH",x=c(0,1),y=c(0,0)),
    evaluated_frames=data.frame(session_id="S1",camera_id="TOP",
      frame_id=0:1),max_reference_distance=.1)
  expect_true(is.data.frame(q$manual_accuracy))
  expect_equal(q$manual_accuracy$n_truth,2)
  expect_false(q$manual_annotation_provenance_independently_verified)
  expect_error(aqt_trajectory_qc(f$obs,f$frames,truth=data.frame()),
               "requires truth, evaluated_frames")
})

test_that("report is new-only, complete and content checksum-locked", {
  f <- qc_fixture()
  q <- aqt_trajectory_qc(f$obs,f$frames,max_jump_px=10)
  r <- aqt_qc_review(q)
  d <- aqt_qc_derive(r)
  out <- tempfile("aqt-qc-report-")
  on.exit(unlink(out,recursive=TRUE),add=TRUE)
  aqt_qc_report(r,d,out)
  want <- c("RAW_OBSERVATIONS.csv","SOURCE_FRAME_MANIFEST.csv",
    "ROW_QUALITY_AUDIT.csv","REVIEWED_TRACKS.csv",
    "DERIVED_KINEMATICS.csv","DERIVED_PATH_SUMMARY.csv",
    "DERIVED_COUNTS.csv","QC_REPORT_MANIFEST.json")
  expect_true(all(file.exists(file.path(out,want))))
  m <- jsonlite::fromJSON(file.path(out,"QC_REPORT_MANIFEST.json"),
                          simplifyVector=FALSE)
  expect_equal(m$n_raw_rows,10)
  expect_identical(m$original_source_sha256,q$raw_sha256)
  expect_true(all(vapply(names(m$output_sha256),function(nm)
    identical(m$output_sha256[[nm]],
      unname(digest::digest(file.path(out,nm),algo="sha256",file=TRUE))),
      logical(1))))
  expect_error(aqt_qc_report(r,d,out),"must be new")
  expect_identical(q$raw,f$obs)
})
