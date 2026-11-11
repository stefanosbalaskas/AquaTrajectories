test_that("identity swaps modify whole future track segments, not individual frames", {
  raw <- aqt_tracks(data.frame(session_id="S1",camera_id="TOP",
    track_id=rep(c("A","B"),each=7),time_s=rep(0:6,2),
    x=c(0,1,2,13,14,15,16,10,11,12,3,4,5,6),y=0),
    units="cm",coordinate_system="tank")
  event <- data.frame(session_id="S1",camera_id="TOP",
    track_a="A",track_b="B",at_s=3,probability_swap=1)
  s <- aqt_identity_switch_scenarios(raw,event,draws=30,seed=123)
  selected <- aqt_identity_draw(s,1)
  expect_true(aqt_tracks_validate(selected))
  expect_equal(selected$x[selected$track_id=="A"],0:6)
  expect_equal(selected$x[selected$track_id=="B"],10:16)
  expect_equal(sum(selected$assignment_changed),8)
  expect_equal(selected$original_track_id[
    selected$track_id=="A" & selected$time_s==4],"B")
  corrected <- aqt_identity_path_sensitivity(s)
  expect_equal(nrow(corrected),60)
  expect_true(all(corrected$path_length==6))
  expect_true(all(corrected$mean_speed==1))
  s0 <- aqt_identity_switch_scenarios(raw,
          transform(event,probability_swap=0),draws=30,seed=123)
  unchanged <- aqt_identity_draw(s0,1)
  expect_equal(unchanged$x[unchanged$track_id=="A"],
               c(0,1,2,13,14,15,16))
  expect_true(all(!unchanged$assignment_changed))
})

test_that("discrete identity scenarios change event outcomes and preserve RNG", {
  raw <- aqt_tracks(data.frame(session_id="S",camera_id="TOP",
    track_id=rep(c("A","B"),each=7),time_s=rep(0:6,2),
    x=c(0,1,2,13,14,15,16,10,11,12,3,4,5,6),y=0))
  sw <- data.frame(session_id="S",camera_id="TOP",
    track_a="A",track_b="B",at_s=3,probability_swap=.5)
  set.seed(88);rng <- .Random.seed
  a <- aqt_identity_switch_scenarios(raw,sw,draws=80,seed=42)
  expect_identical(.Random.seed,rng)
  b <- aqt_identity_switch_scenarios(raw,sw,draws=80,seed=42)
  expect_identical(a$decisions,b$decisions)
  expect_gt(sum(a$decisions),0)
  expect_lt(sum(a$decisions),80)
  events <- data.frame(session_id="S",event_id="feed",
                       start_s=3,end_s=3)
  ep <- aqt_identity_event_sensitivity(a,events,outcome="speed",
    windows=list(baseline=c(-3,0),response=c(0,3)))
  expect_equal(nrow(ep),80*2*2)
  expect_true(all(is.finite(ep$value)))
  response <- ep[ep$epoch=="response",]
  expect_true(any(response$value>2))
  expect_true(any(response$value==1))
  expect_true(all(ep$value[ep$epoch=="baseline"]==1))
})

test_that("bad probabilities and cross-tank swaps are explicitly rejected", {
  raw <- aqt_tracks(data.frame(session_id="S",camera_id="TOP",
     track_id=c("A","A","B","B"),time_s=c(0,1,0,1),
     x=c(0,1,5,6),y=0,tank_id=c("T1","T1","T2","T2")))
  ev <- data.frame(session_id="S",camera_id="TOP",
    track_a="A",track_b="B",at_s=1,probability_swap=.5)
  expect_error(aqt_identity_switch_scenarios(raw,ev,draws=10),
               "between tanks")
  raw2 <- raw
  raw2$tank_id[] <- "T1"
  expect_error(aqt_identity_switch_scenarios(raw2,
      transform(ev,probability_swap=1.1),draws=10),"probabilities")
  expect_error(aqt_identity_switch_scenarios(raw2,
      transform(ev,track_b="A"),draws=10),"distinct")
  expect_error(aqt_identity_switch_scenarios(raw2,
      transform(ev,track_b="C"),draws=10),"present future")
})

test_that("tank treatment sensitivity keeps tank and identity uncertainty separate", {
  ids <- c("C1","C2","T1","T2")
  x <- do.call(rbind,lapply(seq_along(ids),function(i) {
    data.frame(session_id=ids[i],camera_id="TOP",
       track_id=rep(c("A","B"),each=7),
       time_s=rep(0:6,2),
       x=if (i==4) c(0,1,2,13,14,15,16,10,11,12,3,4,5,6)
         else c(0:6,10:16),
       y=0,tank_id=ids[i],
       treatment=if (i<=2) "control" else "treatment")
  }))
  tr <- aqt_tracks(x,units="cm",coordinate_system="tank")
  ev <- data.frame(session_id="T2",camera_id="TOP",
       track_a="A",track_b="B",at_s=3,probability_swap=.5)
  scenarios <- aqt_identity_switch_scenarios(tr,ev,draws=10,seed=7)
  events <- data.frame(session_id=ids,event_id="feed",
      start_s=3,end_s=3)
  fit <- aqt_identity_tank_sensitivity(scenarios,events,
    windows=list(baseline=c(-3,0),response=c(0,3)),
    cluster_bootstrap_draws=100,seed=14)
  expect_equal(nrow(fit$per_draw),10)
  expect_true(all(fit$per_draw$n_tanks_control==2))
  expect_true(all(fit$per_draw$n_tanks_treatment==2))
  expect_true(any(fit$per_draw$estimate>0))
  expect_true(any(fit$per_draw$estimate==0))
  expect_false(fit$uncertainty_combined)
  expect_false(fit$causal_identification)
})
