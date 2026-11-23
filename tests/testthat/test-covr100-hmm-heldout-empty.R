# The heldout fish carry no observed behavioural values in this
# deliberately adverse *synthetic* scenario. No animal state claim follows.
test_that("HMM known-truth recovery rejects entirely unobserved holdouts before scoring", {
  sim <- aqt_hmm_simulate_truth(n_tanks=4L,fish_per_tank=2L,
    n_samples=12L,missing_fraction=0,seed=301L)
  heldout <- !(sim$tank_id %in% c("T001","T002"))
  sim$observed[heldout] <- FALSE
  sim$speed[heldout] <- NA_real_
  expect_error(
    aqt_hmm_recovery_audit(sim,training_tanks=c("T001","T002"),
                           min_segment=3L,max_iter=20L),
    "No contiguous observed fish segments meet min_segment"
  )
})
