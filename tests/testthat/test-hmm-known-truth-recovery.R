test_that("seeded fish truth simulation preserves caller RNG state", {
  set.seed(777)
  previous <- .Random.seed
  x <- aqt_hmm_simulate_truth(
    n_tanks=6,fish_per_tank=2,n_samples=60,seed=13,
    missing_fraction=.05)
  expect_identical(.Random.seed,previous)
  y <- aqt_hmm_simulate_truth(
    n_tanks=6,fish_per_tank=2,n_samples=60,seed=13,
    missing_fraction=.05)
  expect_equal(as.data.frame(x),as.data.frame(y))
  expect_s3_class(x,"aqt_hmm_known_truth")
  expect_equal(nrow(x),720)
  expect_equal(length(unique(x$tank_id)),6)
  expect_equal(length(unique(paste(x$tank_id,x$track_id))),12)
  expect_true(all(x$truth_state %in% c(1L,2L)))
  expect_true(all(is.na(x$speed)==!x$observed))
  expect_true(sum(!x$observed)>0)
  expect_true(attr(x,"aqt_truth_model")$synthetic_only)
  expect_false(attr(x,"aqt_truth_model")$biological_state_certified)
})

test_that("heldout known truth recovers a separated Gaussian state process", {
  x <- aqt_hmm_simulate_truth(
    n_tanks=6,fish_per_tank=2,n_samples=80,
    state_means=c(0,10),state_sds=c(.3,.3),
    transition=matrix(c(.90,.10,.15,.85),2,2,byrow=TRUE),
    initial=c(.55,.45),missing_fraction=0,seed=41)
  result <- aqt_hmm_recovery_audit(
    x,training_tanks=sprintf("T%03d",1:4),
    max_iter=70,tol=1e-6,prior=.01)
  expect_s3_class(result,"aqt_hmm_recovery_audit")
  expect_equal(result$n_training_tanks,4)
  expect_equal(result$n_holdout_tanks,2)
  expect_equal(result$n_training_fish,8)
  expect_equal(result$n_heldout_modelled,320)
  expect_equal(result$n_heldout_missing_or_unsupported,0)
  expect_equal(sum(result$heldout_confusion),320)
  expect_gt(result$heldout_viterbi_truth_accuracy,.97)
  expect_lt(result$transition_mean_abs_error,.20)
  expect_true(all(is.finite(result$fitted_transition)))
  expect_equal(rowSums(result$fitted_transition),c(1,1),
               tolerance=1e-10)
  expect_equal(result$heldout_mean_loglik_per_sample,
               result$heldout_total_loglik/320,
               tolerance=1e-10)
  expect_false(result$real_underwater_validation)
  expect_false(result$biological_welfare_certified)
  expect_false(result$experimental_treatment_inference)
  expect_true(result$holdout_score$no_scoped_fish_overlap)
  expect_true(result$holdout_score$independent_tank_holdout)
})

test_that("synthetic missing observations stay unclassified in heldout audit", {
  x <- aqt_hmm_simulate_truth(
    n_tanks=6,fish_per_tank=2,n_samples=50,
    state_means=c(0,8),state_sds=c(1,1),
    seed=27,missing_fraction=.1)
  a <- aqt_hmm_recovery_audit(
    x,training_tanks=sprintf("T%03d",1:4),
    max_iter=45,tol=1e-5)
  expect_gt(a$n_heldout_missing_or_unsupported,0)
  expect_gt(a$n_heldout_modelled,0)
  expect_equal(a$n_heldout_modelled+
               a$n_heldout_missing_or_unsupported,200)
  expect_equal(sum(a$heldout_confusion),a$n_heldout_modelled)
  expect_true(is.finite(a$heldout_total_loglik))
})

test_that("truth simulation and recovery require scientifically valid design", {
  trans <- matrix(c(.9,.1,.1,.9),2,2,byrow=TRUE)
  expect_error(aqt_hmm_simulate_truth(n_tanks=3),"tank/fish/frame bounds")
  expect_error(aqt_hmm_simulate_truth(fish_per_tank=0),
               "positive integers")
  expect_error(aqt_hmm_simulate_truth(n_samples=5),
               "tank/fish/frame bounds")
  expect_error(aqt_hmm_simulate_truth(missing_fraction=.5),
               "between zero")
  expect_error(aqt_hmm_simulate_truth(seed=NA),
               "nonnegative integer")
  expect_error(aqt_hmm_simulate_truth(
    transition=matrix(1,2,2)),"row-stochastic")
  expect_error(aqt_hmm_simulate_truth(
    transition=trans,initial=c(.2,.2)),"sum to one")
  expect_error(aqt_hmm_simulate_truth(
    state_means=c(3,1)),"increasing")
  expect_error(aqt_hmm_simulate_truth(
    state_sds=c(1,0)),"positive")
  x <- aqt_hmm_simulate_truth(
    n_tanks=5,fish_per_tank=1,n_samples=20,seed=19)
  plain <- x
  class(plain) <- "data.frame"
  expect_error(aqt_hmm_recovery_audit(
    plain,training_tanks=c("T001","T002")),
    "Expected aqt_hmm_known_truth")
  expect_error(aqt_hmm_recovery_audit(x,training_tanks="T001"),
               ">=2 distinct")
  expect_error(aqt_hmm_recovery_audit(
    x,training_tanks=c("T001","T001")),
    ">=2 distinct")
  expect_error(aqt_hmm_recovery_audit(
    x,training_tanks=c("T001","missing")),
    ">=2 distinct")
  expect_error(aqt_hmm_recovery_audit(
    x,training_tanks=sprintf("T%03d",1:4)),
    ">=2 distinct")
})
