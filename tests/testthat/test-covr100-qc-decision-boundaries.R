# Source-preserving acquisition QC boundary checks using only synthetic
# frame manifests and supplied coordinates. No inferred biological identity.

.cov100_qc_fixture <- function() {
  f <- data.frame(session_id="S",camera_id="C",frame_id=0:4,
     time_s=seq(0,.4,by=.1),width_px=100,height_px=80)
  d <- data.frame(session_id="S",camera_id="C",track_id="01",
     frame_id=0:4,time_s=seq(0,.4,by=.1),
     x=c(10,11,12,13,14),y=c(20,20,20,20,20),
     observed=TRUE,detection_confidence=rep(.9,5),
     stringsAsFactors=FALSE)
  list(frames=f,raw=d)
}

test_that("QC refuses incomplete, duplicated and inconsistent frame manifests", {
  z <- .cov100_qc_fixture()
  expect_error(aqt_trajectory_qc(z$raw,NULL),"Complete nonempty frame")
  expect_error(aqt_trajectory_qc(z$raw,z$frames[0,,drop=FALSE]),
               "Complete nonempty frame")
  bad <- z$frames
  bad$session_id[1] <- ""
  expect_error(aqt_trajectory_qc(z$raw,bad),"Invalid frame scope")
  bad <- z$frames
  bad$width_px <- as.character(bad$width_px)
  expect_error(aqt_trajectory_qc(z$raw,bad),"must be numeric")
  bad <- z$frames
  bad$frame_id[1] <- -1
  expect_error(aqt_trajectory_qc(z$raw,bad),"Invalid frame identifiers")
  bad <- z$frames
  bad$height_px[1] <- 0
  expect_error(aqt_trajectory_qc(z$raw,bad),"Invalid frame identifiers")
  bad <- z$frames
  bad$frame_id[3] <- 1
  expect_error(aqt_trajectory_qc(z$raw,bad),"Duplicate frame")
  bad <- z$frames
  bad$time_s[2] <- NA_real_
  expect_error(aqt_trajectory_qc(z$raw,bad),"Frame clock")
  bad <- z$frames
  bad$time_s[3] <- bad$time_s[2]
  expect_error(aqt_trajectory_qc(z$raw,bad),"Frame clock")
})

test_that("acquisition QC rejects false physical axes and incomplete source metadata", {
  z <- .cov100_qc_fixture()
  expect_error(aqt_trajectory_qc(z$raw,z$frames,max_gap_s=0),"finite positive")
  expect_error(aqt_trajectory_qc(z$raw,z$frames,
               min_detection_confidence=-.1),"within")
  expect_error(aqt_trajectory_qc(z$raw,z$frames,
               min_detection_confidence=2),"within")
  expect_error(aqt_trajectory_qc(1,z$frames),"Expected a research bundle")
  bad <- z$raw
  bad$observed <- NULL
  expect_error(aqt_trajectory_qc(bad,z$frames),"Raw observations require")
  bad <- z$raw
  bad$z <- rep(1,nrow(bad))
  expect_error(aqt_trajectory_qc(bad,z$frames),"source-image XY")
  # Preserve the original source and classify explicit character flags.
  bad <- z$raw
  bad$observed <- rep("TRUE",nrow(bad))
  good <- aqt_trajectory_qc(bad,z$frames)
  expect_true(all(good$row_audit$automatically_eligible))
  bad$observed[3] <- "unknown"
  flagged <- aqt_trajectory_qc(bad,z$frames)
  expect_true(flagged$row_audit$flag_invalid_observed[3])
})

test_that("partly missing camera clocks block physical-speed rules and derivation", {
  z <- .cov100_qc_fixture()
  extra_f <- z$frames
  extra_f$camera_id <- "D"
  extra_f$time_s <- NA_real_
  extra_raw <- z$raw
  extra_raw$camera_id <- "D"
  extra_raw$track_id <- "02"
  extra_raw$time_s <- NA_real_
  f <- rbind(z$frames,extra_f)
  raw <- rbind(z$raw,extra_raw)
  expect_error(aqt_trajectory_qc(raw,f,max_speed=5),"requires known timestamps")
  q <- aqt_trajectory_qc(raw,f)
  expect_true(any(q$camera_coverage$n_acquisition_frames==5))
  review <- aqt_qc_review(q)
  expect_null(review$tracks)
  expect_match(review$analysis_blocked,"Mixed clock")
  expect_error(aqt_qc_derive(review),"without source timestamps")
})

test_that("expected track roster rejects duplicates and cameras not in source", {
  z <- .cov100_qc_fixture()
  expect_error(aqt_trajectory_qc(z$raw,z$frames,expected_tracks=data.frame(x=1)),
               "expected_tracks must provide")
  e <- data.frame(session_id=c("S","S"),camera_id="C",track_id="01")
  expect_error(aqt_trajectory_qc(z$raw,z$frames,expected_tracks=e),
               "Invalid or duplicate")
  e <- data.frame(session_id="S",camera_id="OTHER",track_id="01")
  expect_error(aqt_trajectory_qc(z$raw,z$frames,expected_tracks=e),
               "nonexistent camera")
  e <- data.frame(session_id="S",camera_id="C",track_id="UNOBSERVED")
  q <- aqt_trajectory_qc(z$raw,z$frames,expected_tracks=e)
  expect_equal(q$expected_coverage$n_frames_eligible,0)
  expect_equal(q$expected_coverage$n_acquisition_frames,5)
})

test_that("annotated metrics require true source-frame and annotation support", {
  z <- .cov100_qc_fixture()
  truth <- data.frame(session_id="S",camera_id="C",frame_id=0:1,
                      track_id="verified-example",x=c(10,11),y=20)
  bad_frames <- data.frame(session_id="S",camera_id="C",frame_id=100)
  expect_error(aqt_trajectory_qc(z$raw,z$frames,truth=truth,
           evaluated_frames=bad_frames,max_reference_distance=1),
           "Manual evaluation frames must occur")
  in_range <- data.frame(session_id="S",camera_id="C",frame_id=0)
  expect_error(aqt_trajectory_qc(z$raw,z$frames,truth=truth,
           evaluated_frames=in_range,max_reference_distance=1),
           "Truth observations outside")
  evaluated <- data.frame(session_id="S",camera_id="C",frame_id=0:1)
  q <- aqt_trajectory_qc(z$raw,z$frames,truth=truth,
       evaluated_frames=evaluated,max_reference_distance=1,
       expected_tracks=data.frame(session_id="S",camera_id="C",track_id="01"))
  r <- aqt_qc_review(q,data.frame(raw_row=2L,decision="exclude",
                                  reason="Independent frame review"))
  expect_true(is.data.frame(r$reviewed_manual_accuracy))
  expect_true(r$expected_coverage$n_frames_eligible < 5)
  d <- aqt_qc_derive(r)
  target <- tempfile("cov100_qc_report_")
  on.exit(unlink(target,recursive=TRUE,force=TRUE),add=TRUE)
  expect_invisible(aqt_qc_report(r,d,target))
  want <- c("EXPECTED_TRACK_COVERAGE.csv","EXPECTED_TRACK_COVERAGE_REVIEWED.csv",
            "ANNOTATED_ACCURACY_AUTOMATIC.csv","ANNOTATED_ACCURACY_REVIEWED.csv")
  expect_true(all(file.exists(file.path(target,want))))
  expect_equal(utils::read.csv(file.path(target,"DERIVED_COUNTS.csv"))$n_source_rows,5)
})

test_that("review decisions must identify original rows and justified actions", {
  z <- .cov100_qc_fixture()
  q <- aqt_trajectory_qc(z$raw,z$frames)
  expect_error(aqt_qc_review(list()),"Expected aqt_trajectory_qc object")
  expect_error(aqt_qc_review(q,data.frame(x=1)),"Review decisions require")
  d <- data.frame(raw_row=c(1,1),decision="exclude",
                  reason="review")
  expect_error(aqt_qc_review(q,d),"unique valid")
  d <- data.frame(raw_row=6,decision="exclude",
                  reason="review")
  expect_error(aqt_qc_review(q,d),"unique valid")
  d <- data.frame(raw_row=2,decision="defer",
                  reason="review")
  expect_error(aqt_qc_review(q,d),"Every manual decision")
  d <- data.frame(raw_row=2,decision="exclude",reason="")
  expect_error(aqt_qc_review(q,d),"Every manual decision")
  expect_error(aqt_qc_derive(q),"Expected an aqt_qc_review")
  r <- aqt_qc_review(q)
  expect_error(aqt_qc_report(q,directory=tempfile()),"Expected aqt_qc_review")
  derived <- aqt_qc_derive(r)
  manipulated <- derived
  manipulated$review$row_audit$review_eligible[1] <- FALSE
  expect_error(aqt_qc_report(r,manipulated,tempfile()),"must originate")
})
