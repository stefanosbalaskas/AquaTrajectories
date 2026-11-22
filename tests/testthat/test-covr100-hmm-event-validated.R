# Gaussian HMM states are descriptive, not verified physiological states.
.cov100_he_fixture <- function() {
 pieces <- list(); j <- 0L
 for(tank in 1:4) for(fish in 1:2) {
  j <- j+1L
  treated <- tank>=3L
  pieces[[j]] <- data.frame(
    session_id=paste0("S",tank),camera_id="TOP",
    track_id=paste0("F",fish),tank_id=paste0("T",tank),
    treatment=if(treated)"treatment" else "control",
    time_s=0:11,
    speed=if(treated)c(rep(0,6),rep(9,6)) else rep(0,12),
    observed=TRUE)
 }
 decoded <- aqt_hmm_decode(do.call(rbind,pieces),
    state_means=c(0,9),state_sds=c(.3,.3),
    transition=matrix(c(.9,.1,.1,.9),2,2,byrow=TRUE),
    max_gap_s=1.1,state_labels=c("slow","fast"))
 ev <- data.frame(session_id=paste0("S",1:4),event_id="E",
                  start_s=6,end_s=6)
 list(decoded=decoded,events=ev)
}
test_that("HMM event posterior checks state, window, source identities and model metadata",{
 f <- .cov100_he_fixture()
 call <- function(d=f$decoded,ev=f$events,state=2,
                    baseline_window_s=c(-6,0),response_window_s=c(0,6),...)
   aqt_hmm_event_tank_epochs(d,ev,state=state,
     baseline_window_s=baseline_window_s,
     response_window_s=response_window_s,...)
 expect_error(call(d=list()),"Expected decoded HMM fish states")
 bad <- f$decoded;attr(bad,"aqt_hmm_model") <- NULL
 expect_error(call(d=bad),"Missing Gaussian HMM state metadata")
 expect_error(call(state=0),"valid integer HMM")
 expect_error(call(state=3),"valid integer HMM")
 expect_error(call(state=1.5),"valid integer HMM")
 bad <- f$decoded;bad$hmm_p2[1] <- Inf
 expect_error(call(d=bad),"finite-or-missing posterior")
 bad <- f$decoded;bad$hmm_p2[1] <- 1.5
 expect_error(call(d=bad),"finite-or-missing posterior")
 bad <- f$decoded;bad$hmm_p2 <- as.character(bad$hmm_p2)
 expect_error(call(d=bad),"finite-or-missing posterior")
 expect_error(call(baseline_window_s=0),"Event windows require")
 expect_error(call(response_window_s=c(Inf,5)),"Event windows require")
 expect_error(call(baseline_window_s=c(-6,1)),"Baseline must precede")
 expect_error(call(response_window_s=c(-1,6)),"Baseline must precede")
 expect_error(call(min_points=1),"min_points must")
 expect_error(call(min_points=2.5),"min_points must")
 expect_error(call(treatment_levels="control"),"Exactly two distinct")
 expect_error(call(treatment_levels=c("control","control")),"Exactly two distinct")
 bad <- f$decoded;bad$time_s[1] <- Inf
 expect_error(call(d=bad),"HMM timestamps must be finite")
 bad <- f$decoded;bad$track_id[1] <- ""
 expect_error(call(d=bad),"HMM experimental fish/tank identities")
 bad <- f$decoded;bad$session_id[1] <- "SECOND_SESSION"
 expect_error(call(d=bad),"one recording session per tank")
 bad <- f$decoded;bad$camera_id[1] <- "OTHER"
 expect_error(call(d=bad),"one camera view per tank")
 ev <- f$events[-1,,drop=FALSE]
 expect_error(call(ev=ev),"one externally logged event")
 ev <- rbind(f$events,f$events[1,,drop=FALSE])
 expect_error(call(ev=ev),"Duplicate event per session")
 bad <- f$decoded;bad$hmm_p2[] <- NA_real_
 expect_error(call(d=bad),"No observed fish state epochs|Each fish requires supported")
 bad <- f$decoded[
   !(f$decoded$tank_id=="T3" & f$decoded$track_id=="F1" &
     f$decoded$time_s %in% 0:4),,drop=FALSE]
 class(bad) <- class(f$decoded)
 attr(bad,"aqt_hmm_model") <- attr(f$decoded,"aqt_hmm_model")
 expect_error(call(d=bad),"Each fish requires supported")
 e <- call()
 expect_s3_class(e,"aqt_hmm_tank_epochs")
 expect_equal(nrow(e),8)
 expect_false(attr(e,"aqt_hmm_biological_state_certified"))
 expect_error(aqt_hmm_tank_event_contrast(list()),"Expected prepared HMM")
 duplicate <- rbind(e,e[1,,drop=FALSE])
 class(duplicate) <- class(e)
 attr(duplicate,"aqt_experimental_unit") <- "tank"
 expect_error(aqt_hmm_tank_event_contrast(duplicate),"Duplicate tank by epoch")
 result <- aqt_hmm_tank_event_contrast(e,draws=100,seed=41)
 expect_false(result$biological_welfare_certified)
 expect_false(result$causal_identification)
 expect_true(result$posterior_sample_weighted)
})
