# Research workflow status transitions are evidence gates, not fabricated
# findings. These tests use four invented independent tank labels only.
.cov100_research_four <- function(n=4L,nfish=2L) {
  scope <- data.frame(session_id=paste0("S",seq_len(n)),
      camera_id="TOP",tank_id=paste0("T",seq_len(n)),
      treatment=rep(c("control","treatment"),each=n/2))
  frames <- do.call(rbind,lapply(seq_len(n),function(i) data.frame(
       session_id=scope$session_id[i],camera_id="TOP",
       frame_id=0:5,time_s=(0:5)/10,width_px=100,height_px=80)))
  raw <- do.call(rbind,lapply(seq_len(n),function(i) {
    do.call(rbind,lapply(seq_len(nfish),function(k) data.frame(
       session_id=scope$session_id[i],camera_id="TOP",
       track_id=sprintf("%04d",k),frame_id=0:5,time_s=(0:5)/10,
       x=0:5,y=rep(k*3,6),observed=TRUE,
       detection_confidence=.95)))
  }))
  events <- data.frame(session_id=scope$session_id,
       event_id="E",start_s=.3,end_s=.3)
  review <- aqt_qc_review(aqt_trajectory_qc(raw,frames,max_gap_s=.11))
  list(review=review,design=scope,events=events)
}
.cov100_research_cfg <- function(...) {
  utils::modifyList(list(
   max_gap_s=.11,event_clock="same_recording",
   event_windows=list(baseline=c(-.2,0),response=c(0,.2)),
   functional_grid_s=seq(-.2,.2,by=.1),experimental_draws=100L,
   treatment_levels=c("control","treatment")) ,list(...))
}
test_that("research workflow distinguishes blocked, skipped and failed events",{
 f <- .cov100_research_four()
 fun <- function(events=f$events,config=.cov100_research_cfg(),
                 profiles=c("events","functional","experimental"),design=f$design)
   aqt_research_analyze(f$review,profiles=profiles,events=events,
                        design=design,config=config)
 absent <- fun(events=NULL)
 expect_true(all(absent$diagnostics$status[
     absent$diagnostics$profile %in% absent$selected_profiles]=="blocked"))
 clock <- fun(config=list(event_clock="unspecified"))
 expect_true(all(clock$diagnostics$status[
     clock$diagnostics$profile %in% clock$selected_profiles]=="blocked"))
 no_design <- fun(design=NULL)
 expect_identical(no_design$diagnostics$status[
     no_design$diagnostics$profile=="experimental"],"blocked")
 expect_identical(no_design$diagnostics$status[
     no_design$diagnostics$profile=="events"],"complete")
 no_event_epochs <- f$events
 no_event_epochs$start_s <- 100
 no_event_epochs$end_s <- 100
 out <- fun(events=no_event_epochs,profiles="events")
 expect_identical(out$diagnostics$status[
       out$diagnostics$profile=="events"],"skipped")
 bad_outcome <- fun(config=.cov100_research_cfg(event_outcome="z"),
       profiles=c("events","functional"))
 expect_identical(bad_outcome$diagnostics$status[
       bad_outcome$diagnostics$profile=="events"],"failed")
 expect_identical(bad_outcome$diagnostics$status[
       bad_outcome$diagnostics$profile=="functional"],"failed")
 no_contrast <- fun(profiles="experimental")
 expect_identical(no_contrast$diagnostics$status[
       no_contrast$diagnostics$profile=="experimental"],"skipped")
 wrong_levels <- fun(config=.cov100_research_cfg(
      experimental_contrast=TRUE,treatment_levels=c("control","other")),
      profiles="experimental")
 expect_identical(wrong_levels$diagnostics$status[
       wrong_levels$diagnostics$profile=="experimental"],"blocked")
 no_epoch <- fun(events=no_event_epochs,config=.cov100_research_cfg(
      experimental_contrast=TRUE),profiles="experimental")
 expect_identical(no_epoch$diagnostics$status[
       no_epoch$diagnostics$profile=="experimental"],"blocked")
 valid <- fun(config=.cov100_research_cfg(experimental_contrast=TRUE),
             profiles="experimental")
 expect_identical(valid$diagnostics$status[
       valid$diagnostics$profile=="experimental"],"complete")
 expect_equal(valid$statistical_models$tank_contrast$n_tanks_control,2)
 expect_equal(valid$statistical_models$tank_contrast$n_tanks_treatment,2)
 expect_false(valid$statistical_models$tank_contrast$causal_identification)
})
test_that("scientific inferential pathways cannot count one camera as independent tanks",{
 f <- .cov100_research_four()
 one <- .cov100_research_four(n=2L,nfish=3L)
 result <- aqt_research_analyze(one$review,profiles="experimental",
       events=one$events,design=one$design,
       config=.cov100_research_cfg(experimental_contrast=TRUE))
 expect_identical(result$diagnostics$status[
       result$diagnostics$profile=="experimental"],"blocked")
 two <- aqt_research_analyze(f$review,
       profiles=c("experimental","functional"),events=f$events,
       design=f$design,
       config=.cov100_research_cfg(experimental_contrast=TRUE,
          functional_contrast=TRUE))
 expect_identical(two$diagnostics$status[
       two$diagnostics$profile=="experimental"],"complete")
 expect_true(is.list(two$statistical_models$functional_contrast))
 expect_true(is.data.frame(two$statistical_models$functional_contrast$curve))
 expect_false(two$statistical_models$functional_contrast$causal_identification)
 invalid_model <- aqt_research_analyze(f$review,
       profiles=c("functional","experimental"),events=f$events,
       design=f$design,config=.cov100_research_cfg(
          experimental_contrast=FALSE,functional_model="nested_nlme"))
 expect_true(is.list(invalid_model$statistical_models))
 expect_true(any(c("functional_model","functional_model_error") %in%
       names(invalid_model$statistical_models)))
})
test_that("research movement and schooling expose no-fish and pair-cap failures",{
 f <- .cov100_research_four(n=2L,nfish=2L)
 too_many <- aqt_research_analyze(f$review,
       profiles=c("movement","schooling"),config=list(max_pairs=1L))
 expect_identical(too_many$diagnostics$status[
       too_many$diagnostics$profile=="movement"],"complete")
 expect_identical(too_many$diagnostics$status[
       too_many$diagnostics$profile=="schooling"],"failed")
 single <- .cov100_research_four(n=2L,nfish=1L)
 skip <- aqt_research_analyze(single$review,
       profiles=c("schooling","uncertainty"),
       config=list(uncertainty=list(enabled=FALSE)))
 expect_identical(skip$diagnostics$status[
       skip$diagnostics$profile=="schooling"],"skipped")
 expect_identical(skip$diagnostics$status[
       skip$diagnostics$profile=="uncertainty"],"skipped")
 expect_false(skip$provenance$fish_identity_certified)
})
