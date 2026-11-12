.aqt_aci_fixture <- function() {
  s <- seq(0,50,by=10)
  data.frame(session_id="S",trial_id=paste0("trial",1:6),
    fish_id="F",tank_id="T1",
    condition="closed_loop",
    opportunity_s=s,end_s=s+5,
    action_s=c(1,11,21,NA,NA,NA),
    detection_s=c(1.1,NA,21.2,31.1,41.3,NA),
    command_s=c(1.2,NA,NA,31.2,NA,NA),
    actuator_s=c(1.4,NA,NA,31.4,NA,NA),
    response_s=c(1.6,NA,NA,31.8,NA,NA))
}

test_that("ACI telemetry audits real action and device stages without imputation", {
  t <- aqt_aci_trials(.aqt_aci_fixture())
  expect_s3_class(t,"aqt_aci_trials")
  expect_equal(nrow(t),6)
  expect_equal(sum(t$has_action),3)
  expect_equal(sum(t$has_detection),4)
  expect_equal(sum(t$has_actuation),2)
  expect_equal(which(t$false_trigger),c(4,5))
  expect_equal(which(t$false_actuation),4)
  expect_equal(t$detector_latency_s[c(1,3)],c(.1,.2),
               tolerance=1e-10)
  expect_true(is.na(t$detector_latency_s[2]))
  expect_equal(t$end_to_end_s[1],.4,tolerance=1e-10)
  expect_true(all(is.na(t$end_to_end_s[-1])))
  expect_false(attr(t,"annotation_certified"))
  expect_false(attr(t,"clock_synchronization_certified"))
})

test_that("ACI loop distinguishes opportunities, true triggers and false triggers", {
  t <- aqt_aci_trials(.aqt_aci_fixture())
  m <- aqt_aci_loop_metrics(t)
  expect_equal(m$n_opportunities,6)
  expect_equal(m$n_actions,3)
  expect_equal(m$n_no_action,3)
  expect_equal(m$n_true_detections,2)
  expect_equal(m$n_missed_detections,1)
  expect_equal(m$n_false_detections,2)
  expect_equal(m$n_true_activations,1)
  expect_equal(m$n_false_activations,1)
  expect_equal(m$p_activation_given_action,1/3)
  expect_equal(m$p_activation_given_no_action,1/3)
  expect_equal(m$contingency_difference,0,tolerance=1e-12)
  expect_false(m$causal_agency_inference)
  lat <- aqt_aci_latency_summary(t)
  expect_equal(lat$n_complete,1)
  expect_equal(lat$complete_fraction,1/6)
  expect_equal(lat$detector_median_s,.15,tolerance=1e-10)
  expect_equal(lat$controller_median_s,.1,tolerance=1e-10)
  expect_equal(lat$actuator_median_s,.2,tolerance=1e-10)
  expect_equal(lat$end_to_end_median_s,.4,tolerance=1e-10)
})

test_that("unobserved action class never produces spurious contingency evidence", {
  d <- .aqt_aci_fixture()
  d$action_s[] <- NA_real_
  # Keep false triggers but their complete animal actions are absent.
  t <- aqt_aci_trials(d)
  m <- aqt_aci_loop_metrics(t)
  expect_equal(m$n_actions,0)
  expect_true(is.na(m$p_activation_given_action))
  expect_true(is.na(m$contingency_difference))
  expect_equal(m$p_activation_given_no_action,2/6)
  expect_true(is.na(aqt_aci_latency_summary(t)$end_to_end_median_s))
})

test_that("ACI trials reject impossible clock order and unlogged stages", {
  d <- .aqt_aci_fixture()
  d$command_s[2] <- 11.3
  expect_error(aqt_aci_trials(d),"required predecessor")
  d <- .aqt_aci_fixture()
  d$actuator_s[1] <- 1.05
  expect_error(aqt_aci_trials(d),"Non-monotone")
  d <- .aqt_aci_fixture()
  d$detection_s[1] <- -1
  expect_error(aqt_aci_trials(d),"declared trial window")
  d <- .aqt_aci_fixture()
  d$end_s[1] <- d$opportunity_s[1]
  expect_error(aqt_aci_trials(d),"positive time window")
  d <- .aqt_aci_fixture()
  d$trial_id[2] <- d$trial_id[1]
  expect_error(aqt_aci_trials(d),"Duplicate animal opportunity")
  d <- .aqt_aci_fixture()
  d$fish_id[2] <- ""
  expect_error(aqt_aci_trials(d),"Missing trial")
})

test_that("ACI group scope includes session and requested columns", {
  d <- .aqt_aci_fixture()
  t <- aqt_aci_trials(d)
  expect_error(aqt_aci_loop_metrics(t,group_cols="fish_id"),
      "must include session")
  expect_error(aqt_aci_latency_summary(t,group_cols=c("session_id","missing")),
      "existing unique")
  expect_equal(aqt_aci_loop_metrics(t,
      group_cols=c("session_id","tank_id","condition"))$n_opportunities,
      6)
})
