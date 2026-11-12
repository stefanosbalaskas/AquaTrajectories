.aqt_hmm_event_fixture <- function() {
  pieces <- list();j <- 0L
  for (tank in 1:4) for (fish in 1:2) {
    j <- j+1L
    treated <- tank>=3L
    pieces[[j]] <- data.frame(
      session_id=paste0("S",tank),camera_id="TOP",
      track_id=paste0("F",fish),tank_id=paste0("T",tank),
      treatment=if(treated) "treatment" else "control",
      time_s=0:11,
      speed=if(treated) c(rep(0,6),rep(9,6)) else rep(0,12),
      observed=TRUE)
  }
  d <- do.call(rbind,pieces)
  d <- aqt_hmm_decode(
    d,state_means=c(0,9),state_sds=c(.3,.3),
    transition=matrix(c(.9,.1,.1,.9),2,2,byrow=TRUE),
    max_gap_s=1.1,state_labels=c("slow","fast"))
  ev <- data.frame(session_id=paste0("S",1:4),
                   event_id="feeding",start_s=6,end_s=6)
  list(decoded=d,events=ev)
}

test_that("posterior states aggregate first by fish then independent tank", {
  f <- .aqt_hmm_event_fixture()
  epochs <- aqt_hmm_event_tank_epochs(
    f$decoded,f$events,state=2,
    baseline_window_s=c(-6,0),response_window_s=c(0,6),
    min_points=3)
  expect_s3_class(epochs,"aqt_hmm_tank_epochs")
  expect_equal(nrow(epochs),8)
  expect_equal(length(unique(epochs$tank_id)),4)
  expect_true(all(epochs$n_fish==2L))
  expect_true(all(epochs$n_valid_fish_samples==12L))
  expect_true(all(epochs$n_total_fish_samples==12L))
  expect_true(all(epochs$value>=0 & epochs$value<=1))
  control <- epochs[epochs$treatment=="control",]
  treated <- epochs[epochs$treatment=="treatment",]
  expect_lt(max(control$value),.01)
  expect_lt(max(treated$value[treated$epoch=="baseline"]),.01)
  expect_gt(min(treated$value[treated$epoch=="response"]),.99)
  fish_epochs <- attr(epochs,"aqt_hmm_fish_epochs")
  expect_equal(nrow(fish_epochs),16)
  expect_equal(unique(epochs$state_label),"fast")
  expect_identical(attr(epochs,"aqt_experimental_unit"),"tank")
  expect_true(attr(epochs,"aqt_sample_weighted"))
  expect_false(attr(epochs,"aqt_hmm_biological_state_certified"))
})

test_that("treatment contrast bootstraps tanks and preserves RNG", {
  f <- .aqt_hmm_event_fixture()
  e <- aqt_hmm_event_tank_epochs(f$decoded,f$events,
      state=2,baseline_window_s=c(-6,0),
      response_window_s=c(0,6))
  set.seed(444)
  old_rng <- .Random.seed
  contrast <- aqt_hmm_tank_event_contrast(
    e,draws=199,level=.9,seed=101)
  expect_identical(.Random.seed,old_rng)
  expect_s3_class(contrast,"aqt_hmm_tank_event_contrast")
  expect_gt(contrast$estimate,.98)
  expect_equal(contrast$n_tanks_control,2L)
  expect_equal(contrast$n_tanks_treatment,2L)
  expect_equal(nrow(contrast$per_tank),4)
  expect_equal(nrow(contrast$fish_epoch_audit),16)
  expect_equal(contrast$draws,199L)
  expect_lte(contrast$lower,contrast$upper)
  expect_false(contrast$causal_identification)
  expect_false(contrast$biological_welfare_certified)
  expect_false(contrast$individual_fish_or_video_frames_are_experimental_units)
  expect_true(contrast$posterior_sample_weighted)
})

test_that("HMM event analysis refuses incomplete fish epochs and repeated events", {
  f <- .aqt_hmm_event_fixture()
  w <- list(baseline_window_s=c(-6,0),response_window_s=c(0,6))
  basecall <- function(d=f$decoded,ev=f$events,...)
    aqt_hmm_event_tank_epochs(d,ev,state=2,
      baseline_window_s=c(-6,0),response_window_s=c(0,6),...)
  expect_error(basecall(state=3),"unused argument")
  expect_error(aqt_hmm_event_tank_epochs(
    f$decoded,f$events,state=3,
    baseline_window_s=c(-6,0),response_window_s=c(0,6)),
    "valid integer")
  expect_error(basecall(
    baseline_window_s=c(-6,1)),
    "matched by multiple actual arguments")
  ev <- rbind(f$events,
    data.frame(session_id="S1",event_id="second",
               start_s=8,end_s=8))
  expect_error(basecall(ev=ev),"one externally logged event")
  incomplete <- f$decoded[
    !(f$decoded$tank_id=="T3" &
      f$decoded$track_id=="F1" &
      f$decoded$time_s %in% 0:4),,drop=FALSE]
  expect_error(basecall(d=incomplete),
               "Each fish requires supported")
  no_tank <- f$decoded
  no_tank$tank_id <- NULL
  expect_error(basecall(d=no_tank),
               "with tank and treatment")
  reassigned <- f$decoded
  reassigned$treatment[1] <- "treatment"
  expect_error(basecall(d=reassigned),
               "Treatment varies within tank")
  one_tank_per_arm <- f$decoded[
    f$decoded$tank_id %in% c("T1","T3"),,drop=FALSE]
  matching_events <- f$events[
    f$events$session_id %in% c("S1","S3"),,drop=FALSE]
  expect_error(basecall(d=one_tank_per_arm,ev=matching_events),
               ">=2 independent tanks")
  expect_error(aqt_hmm_tank_event_contrast(f$decoded),
               "Expected prepared")
})

test_that("sample count support of gaps is disclosed and never imputed", {
  f <- .aqt_hmm_event_fixture()
  missing <- f$decoded
  idx <- which(missing$tank_id=="T4" &
                missing$track_id=="F1" &
                missing$time_s==8)
  missing$hmm_p2[idx] <- NA_real_
  e <- aqt_hmm_event_tank_epochs(
    missing,f$events,state=2,
    baseline_window_s=c(-6,0),response_window_s=c(0,6),
    min_points=3)
  fish <- attr(e,"aqt_hmm_fish_epochs")
  row <- fish[fish$tank_id=="T4" & fish$track_id=="F1" &
                 fish$epoch=="response",]
  expect_equal(row$n_valid,5)
  expect_equal(row$n_samples,6)
  t4 <- e[e$tank_id=="T4" & e$epoch=="response",]
  expect_equal(t4$n_valid_fish_samples,11)
  expect_equal(t4$n_total_fish_samples,12)
})
