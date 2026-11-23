# Unit tests for researcher-supplied publication inventories use only
# synthetic acquisition data; no new results are estimated by the exporter.
.cov100_publish_audit_study <- function() {
 f <- data.frame(session_id="S",camera_id="C",frame_id=0:3,
                 time_s=(0:3)/10,width_px=100,height_px=80)
 d <- data.frame(session_id="S",camera_id="C",track_id="F",
                 frame_id=0:3,time_s=(0:3)/10,
                 x=10:13,y=20,observed=TRUE,
                 detection_confidence=.9)
 r <- aqt_qc_review(aqt_trajectory_qc(d,f,max_gap_s=.11))
 aqt_research_analyze(r,profiles="movement")
}
test_that("publication eligibility exposes absent camera coverage without fabricating it",{
 study <- .cov100_publish_audit_study()
 study$audit$camera_coverage <- data.frame()
 plan <- aqt_research_figure_plan(study,max_scopes=1)
 row <- plan[plan$figure_id=="F01_SOURCE_COVERAGE",,drop=FALSE]
 expect_equal(nrow(row),1L)
 expect_false(row$eligible)
 expect_equal(row$n_used,0L)
 expect_match(row$reason,"Missing acquisition-frame")
})
test_that("analysis archive includes a declared experimental roster and rejects non-tables",{
 study <- .cov100_publish_audit_study()
 study$audit$expected_coverage <- data.frame(
   session_id="S",camera_id="C",track_id="F",
   declared_fish_count=1L)
 root <- tempfile("cov100_roster_");dir.create(root)
 on.exit(unlink(root,recursive=TRUE,force=TRUE),add=TRUE)
 output <- file.path(root,"export")
 expect_invisible(aqt_research_export(study,output))
 expect_true(file.exists(file.path(output,
        "audit","declared_roster_coverage.csv")))
 malformed <- study
 malformed$audit$eligibility <- list(disallowed=TRUE)
 output2 <- file.path(root,"bad")
 expect_error(aqt_research_export(malformed,output2),
              "Export tables must be data.frames")
 expect_false(dir.exists(output2))
})
test_that("publication prose explicitly records that no figures were withheld",{
 study <- .cov100_publish_audit_study()
 catalog <- data.frame(figure_id="SYNTHETIC",
   kind="coverage",title="Synthetic source count",
   caption="Synthetic source-qualified positions",
   session_id="S",camera_id="C",eligible=TRUE,
   status="complete",files="figures/SYNTHETIC.pdf",
   reason="",n_used=3L)
 lines <- aquaTrajectories:::.aqt_pub_report_lines(
    study,catalog,data_origin="synthetic")
 idx <- which(lines=="## Withheld figures and drawing failures")
 expect_equal(lines[idx+2L],"None.")
 expect_true(any(grepl("Synthetic source count",lines,fixed=TRUE)))
 expect_true(any(grepl("not independently validated",lines,fixed=TRUE) |
                 grepl("not an independently validated",lines,fixed=TRUE)))
})
