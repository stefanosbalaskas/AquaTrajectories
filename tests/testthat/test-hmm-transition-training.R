.aqt_transition_fixture <- function(tanks=c("T1","T2","T3","T4")) {
  # Deliberately distinct fish/tank scopes; fixed, well-separated emissions.
  n <- 40L
  d <- lapply(seq_along(tanks),function(i) {
    states <- if(i%%2L) rep(c(1L,2L,1L,2L),each=10) else
      rep(c(2L,1L,2L,1L),each=10)
    data.frame(session_id=paste0("S",i),camera_id="TOP",
      track_id=paste0("F",i),tank_id=tanks[i],
      treatment=if(i%%2L) "control" else "treatment",
      time_s=seq(0,n-1L)/10,
      speed=ifelse(states==1L,0,10))
  })
  do.call(rbind,d)
}

test_that("fixed emission Baum Welch estimates stochastic transitions", {
  x <- .aqt_transition_fixture()
  fit <- aqt_hmm_transition_fit(
    x,state_means=c(0,10),state_sds=c(.5,.5),
    max_gap_s=.11,prior=.001,max_iter=300,tol=1e-8)
  expect_s3_class(fit,"aqt_hmm_transition_fit")
  expect_true(all(is.finite(fit$transition)))
  expect_true(all(fit$transition>0))
  expect_equal(rowSums(fit$transition),c(1,1),tolerance=1e-11)
  expect_equal(sum(fit$initial),1,tolerance=1e-11)
  expect_equal(fit$n_sequences,4)
  expect_equal(fit$n_training_fish,4)
  expect_equal(fit$n_modelled_samples,160)
  expect_true(all(is.finite(fit$loglik_history)))
  expect_equal(tail(fit$loglik_history,1),fit$loglik,tolerance=1e-10)
  expect_gte(fit$loglik,
             fit$loglik_history[1]-1e-4)
  expect_lt(fit$transition[1,2],.5)
  expect_lt(fit$transition[2,1],.5)
  expect_false(fit$emission_parameters_estimated)
  expect_true(fit$transition_parameters_estimated)
  expect_false(fit$tank_treatment_inference)
  expect_false(fit$welfare_certified)
})

test_that("independent tank holdout scoring excludes both tank and fish leakage", {
  train <- .aqt_transition_fixture()
  fit <- aqt_hmm_transition_fit(
    train,state_means=c(0,10),state_sds=c(1,1),
    max_gap_s=.11,max_iter=150,tol=1e-7)
  holdout <- .aqt_transition_fixture(c("T5","T6"))
  holdout$session_id <- c(rep("S5",40),rep("S6",40))
  holdout$track_id <- c(rep("F5",40),rep("F6",40))
  score <- aqt_hmm_holdout_score(holdout,fit)
  expect_s3_class(score,"aqt_hmm_holdout_score")
  expect_equal(score$n_modelled,80)
  expect_equal(score$n_sequences,2)
  expect_equal(score$n_holdout_tanks,2)
  expect_true(score$independent_tank_holdout)
  expect_true(score$no_scoped_fish_overlap)
  expect_true(is.finite(score$total_loglik))
  expect_equal(score$mean_loglik_per_sample,
               score$total_loglik/80,tolerance=1e-12)
  expect_false(score$state_truth_certified)
  expect_false(score$calibration_certified)

  # A renamed fish in a training tank is NOT independent validation.
  reused_tank <- holdout
  reused_tank$tank_id <- c(rep("T1",40),rep("T6",40))
  expect_error(aqt_hmm_holdout_score(reused_tank,fit),"tanks overlap")
  expect_error(aqt_hmm_holdout_score(train[1:8,],fit),
               "scope overlaps")
})

test_that("heldout scoring audits missing or unsupported fish observations", {
  train <- .aqt_transition_fixture()
  fit <- aqt_hmm_transition_fit(
    train,state_means=c(0,10),state_sds=c(1,1),
    max_gap_s=.11,max_iter=40)
  y <- data.frame(session_id="new",camera_id="TOP",track_id="new",
    tank_id="unseen",time_s=0:11/10,
    speed=c(rep(0,5),NA,NA,rep(10,5)))
  z <- aqt_hmm_holdout_score(y,fit)
  expect_equal(z$n_input,12)
  expect_equal(z$n_modelled,10)
  expect_equal(z$n_sequences,2)
  expect_equal(z$n_missing_or_unsupported,2)
})

test_that("transition fitting rejects statistically invalid inputs", {
  x <- .aqt_transition_fixture()
  fitting <- function(d=x,...) aqt_hmm_transition_fit(
    d,state_means=c(0,10),state_sds=c(1,1),
    max_gap_s=.11,...)
  expect_error(fitting(prior=0),"Dirichlet")
  expect_error(fitting(max_iter=1),"max_iter")
  expect_error(fitting(tol=0),"tol")
  expect_error(fitting(start_transition=matrix(1,2,2)),
               "row-stochastic")
  expect_error(fitting(start_initial=c(.5,.4)),"probability vector")
  expect_error(fitting(x[1:40,]),">=2 independently")
  wrong <- x
  wrong$track_id <- "same"
  wrong$session_id <- "same"
  wrong$tank_id <- "same"
  wrong$time_s <- rep(seq(0,39)/10,4)
  expect_error(fitting(wrong),"Duplicate/nonincreasing")
  fit <- fitting(max_iter=20)
  expect_error(aqt_hmm_holdout_score(x,fit),"scope overlaps")
  expect_error(aqt_hmm_holdout_score(x[,setdiff(names(x),"tank_id")],fit),
               "schema")
  expect_error(aqt_hmm_holdout_score(x,fit,
               require_disjoint_tanks=NA),"single logical")
})

test_that("expected transition mass counts only observed within-segment steps", {
  train <- .aqt_transition_fixture()
  fit <- aqt_hmm_transition_fit(
    train,state_means=c(0,10),state_sds=c(.5,.5),
    max_gap_s=.11,prior=.01,tol=1e-8,max_iter=100)
  # Four 40-point fish sequences contribute 4*(40-1) transitions.
  # No transition may be attributed between separate tanks or fish.
  expect_equal(sum(fit$expected_transition_counts),
               4*(40-1),tolerance=1e-7)
  expect_equal(sum(fit$expected_state_observations),160,
               tolerance=1e-7)
  expect_equal(fit$n_training_fish,4)
  expect_true(fit$has_tank_id)
  expect_setequal(fit$training_tanks,c("T1","T2","T3","T4"))
})
