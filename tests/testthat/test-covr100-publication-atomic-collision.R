# Test a genuine atomic publication collision by creating an output
# path AFTER initial validation but BEFORE the terminal atomic rename.
# The underlying synthetic source is never altered.
.cov100_collision_study <- function() {
 frames <- data.frame(session_id="S",camera_id="TOP",frame_id=0:3,
     time_s=(0:3)/10,width_px=100,height_px=80)
 raw <- data.frame(session_id="S",camera_id="TOP",track_id="F",
     frame_id=0:3,time_s=(0:3)/10,x=10:13,y=20,
     observed=TRUE,detection_confidence=.9)
 review <- aqt_qc_review(aqt_trajectory_qc(raw,frames,max_gap_s=.11))
 aqt_research_analyze(review,profiles="movement")
}
test_that("scientific publication rejects a concurrent output collision and clears stage", {
 study <- .cov100_collision_study()
 root <- tempfile("cov100_atomic_")
 dir.create(root)
 on.exit(unlink(root,recursive=TRUE,force=TRUE),add=TRUE)
 target <- file.path(root,"publication")
 old <- getFromNamespace("aqt_research_export","aquaTrajectories")
 injected <- function(study,directory) {
   dir.create(target)
   writeLines("external writer occupied destination",
              file.path(target,"collision.txt"))
   old(study,directory)
 }
 testthat::with_mocked_bindings(
   expect_error(aqt_research_publish(study,target,formats="pdf",
                          data_origin="synthetic"),
                "Could not publish complete scientific report"),
   aqt_research_export=injected,
   .package="aquaTrajectories")
 expect_true(file.exists(file.path(target,"collision.txt")))
 expect_false(file.exists(file.path(target,"REPORT.md")))
 remnants <- list.files(root,all.files=TRUE)
 expect_false(any(grepl("^\\.aqt-publication-",remnants)))
})
