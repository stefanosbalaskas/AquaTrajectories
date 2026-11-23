# Evidence-gated workflow statuses are tested using synthetic single-frame
# sources, never by inventing an independent biological sampling unit.
.cov100_fault_review <- function(nframes=1L) {
 frames <- data.frame(session_id="S",camera_id="C",
       frame_id=seq_len(nframes)-1L,
       time_s=(seq_len(nframes)-1L)*.1,
       width_px=100,height_px=80)
 raw <- data.frame(session_id="S",camera_id="C",track_id="F",
       frame_id=frames$frame_id,time_s=frames$time_s,
       x=seq_len(nframes),y=rep(2,nframes),observed=TRUE,
       detection_confidence=rep(.9,nframes))
 aqt_qc_review(aqt_trajectory_qc(raw,frames,max_gap_s=.11))
}
test_that("research analysis treats a present-but-empty event log as no events",{
 review <- .cov100_fault_review(3L)
 empty <- data.frame(session_id=character(),event_id=character(),
                      start_s=numeric(),end_s=numeric())
 analysis <- aqt_research_analyze(review,
    profiles=c("events","functional"),events=empty,
    config=list(event_clock="same_recording"))
 expect_true(all(analysis$diagnostics$status[
    analysis$diagnostics$profile %in% c("events","functional")]=="blocked"))
 expect_true(all(grepl("Independently logged event times",
    analysis$diagnostics$reason[
      analysis$diagnostics$profile %in% c("events","functional")])))
})
test_that("conditional position sensitivity fails visibly when source has no movement intervals",{
 review <- .cov100_fault_review(1L)
 report <- aqt_research_analyze(review,profiles="uncertainty",
    config=list(uncertainty=list(enabled=TRUE,
               sigma=.1,draws=20L,seed=13L)))
 q <- report$diagnostics[report$diagnostics$profile=="uncertainty",]
 expect_identical(q$status,"failed")
 expect_match(q$reason,"No eligible movement intervals")
 expect_null(report$uncertainty)
 expect_false(report$provenance$physical_calibration_certified)
})
