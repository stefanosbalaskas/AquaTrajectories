# Controlled, package-local faults in final publication transactions.
# These tests never modify real inputs or global R/base functions.
.cov100_fs_review <- function() {
  frames <- data.frame(session_id="S",camera_id="TOP",frame_id=0:5,
      time_s=(0:5)/10,width_px=100,height_px=100)
  source <- data.frame(session_id="S",camera_id="TOP",track_id="A",
      frame_id=0:5,time_s=(0:5)/10,x=1:6,y=2:7,
      observed=TRUE,detection_confidence=.9)
  aqt_qc_review(aqt_trajectory_qc(source,frames,max_gap_s=.11))
}

test_that("publication specification stops on failed atomic final commit",{
  track <- aqt_simulate_tracks(n_fish=2L,n_frames=12L,
     dimension=2L,fps=10,seed=28L)
  spec <- aqt_viz2_spec(track,figure="paths",gap_limit_s=.11)
  parent <- tempfile("cov100_viz_fs_");base::dir.create(parent)
  on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
  dest <- file.path(parent,"uncommitted")
  testthat::with_mocked_bindings({
    expect_error(aqt_viz2_export(spec,dest,formats="pdf"),
                 "Could not atomically publish staged publication figure")
  },file.rename=function(from,to) {
     if(startsWith(basename(from),".aqt-viz2-stage-"))
       return(FALSE)
     base::file.rename(from,to)
  },.package="aquaTrajectories")
  expect_false(dir.exists(dest))
  expect_false(spec$provenance$independently_certified_biological_accuracy)
})

test_that("QC reporting refuses a failed final atomic publication",{
  review <- .cov100_fs_review()
  hash <- review$original_source_sha256
  parent <- tempfile("cov100_qcr_fs_");base::dir.create(parent)
  on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
  dest <- file.path(parent,"qc")
  testthat::with_mocked_bindings({
    expect_error(aqt_qc_report(review,directory=dest),
                 "Could not publish complete QC report directory")
  },file.rename=function(...) FALSE,.package="aquaTrajectories")
  expect_false(dir.exists(dest))
  expect_identical(review$original_source_sha256,hash)
})

test_that("figure exporter reports vanished output instead of publishing manifest",{
  parent <- tempfile("cov100_missing_figure_");base::dir.create(parent)
  on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
  dest <- file.path(parent,"figure")
  testthat::with_mocked_bindings({
    expect_error(aqt_figure_export(
      function() graphics::plot(1:5,1:5),dest,formats="pdf"),
      "Figure output is missing or empty")
  },file.exists=function(path) {
    ok <- base::file.exists(path)
    ok[grepl("figure\\.pdf$",path)] <- FALSE
    ok
  },.package="aquaTrajectories")
  expect_false(dir.exists(dest))
})
