# Externally logged ACI events record device timing only, not agency.
.cov100_aci_timeline <- function() {
 data.frame(session_id="S",trial_id=c("E1","E2"),fish_id="F",
   opportunity_s=c(0,10),end_s=c(5,15),
   action_s=c(1,NA_real_),detection_s=c(1.2,11),
   command_s=c(1.3,11.2),actuator_s=c(1.5,11.5),
   response_s=c(2,NA_real_))
}
test_that("ACI closed-loop timestamps reject incomplete telemetry and nonfinite clock sources",{
 d <- .cov100_aci_timeline()
 expect_error(aqt_aci_trials(list()),"Expected nonempty ACI opportunity")
 expect_error(aqt_aci_trials(d[FALSE,,drop=FALSE]),"Expected nonempty ACI opportunity")
 bad <- d;bad$opportunity_s <- as.character(bad$opportunity_s)
 expect_error(aqt_aci_trials(bad),"numeric and non-infinite")
 bad <- d;bad$detection_s[1] <- Inf
 expect_error(aqt_aci_trials(bad),"numeric and non-infinite")
 bad <- d;bad$command_s[1] <- .5
 expect_error(aqt_aci_trials(bad),"Non-monotone animal/device")
 bad <- d;bad$actuator_s[1] <- NA_real_
 expect_error(aqt_aci_trials(bad),"Device stage exists without")
 out <- aqt_aci_trials(d)
 expect_s3_class(out,"aqt_aci_trials")
 expect_identical(out$false_trigger,c(FALSE,TRUE))
 expect_identical(out$false_actuation,c(FALSE,TRUE))
 expect_equal(out$end_to_end_s[1],.5,tolerance=1e-12)
 expect_true(is.na(out$end_to_end_s[2]))
 expect_false(attr(out,"animal_agency_claimed"))
})
test_that("ACI contingency and latency refuse unvalidated logs, retain unknowns",{
 expect_error(aqt_aci_loop_metrics(list()),"Expected aqt_aci_trials log")
 expect_error(aqt_aci_latency_summary(list()),"Expected aqt_aci_trials log")
 x <- aqt_aci_trials(.cov100_aci_timeline())
 expect_error(aqt_aci_loop_metrics(x,group_cols="fish_id"),
              "must include session_id")
 expect_error(aqt_aci_latency_summary(x,group_cols="fish_id"),
              "must include session_id")
 summary <- aqt_aci_loop_metrics(x,group_cols="session_id")
 expect_equal(summary$n_actions,1)
 expect_equal(summary$n_false_activations,1)
 expect_equal(summary$p_activation_given_action,1)
 expect_equal(summary$p_activation_given_no_action,1)
 expect_equal(summary$contingency_difference,0)
 timing <- aqt_aci_latency_summary(x,group_cols="session_id")
 expect_equal(timing$n_complete,1)
 expect_equal(timing$complete_fraction,.5)
 expect_equal(timing$end_to_end_median_s,.5,tolerance=1e-12)
 expect_false(timing$clock_synchronization_certified)
});
