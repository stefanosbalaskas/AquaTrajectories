# Seeded latent states are known only because this fixture is synthetic.
test_that("synthetic HMM restores ABSENT global RNG state without leaking a seed",{
 had<-exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE)
 if(had) old<-get(".Random.seed",envir=.GlobalEnv)
 on.exit({
   if(had)assign(".Random.seed",old,envir=.GlobalEnv)
   else if(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
     rm(".Random.seed",envir=.GlobalEnv)
 },add=TRUE)
 if(had) rm(".Random.seed",envir=.GlobalEnv)
 expect_false(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
 d<-aqt_hmm_simulate_truth(n_tanks=4,fish_per_tank=1,n_samples=8,
                          seed=31,sampling_dt_s=.1)
 expect_false(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
 expect_equal(nrow(d),32L)
 expect_true(attr(d,"aqt_truth_model")$synthetic_only)
 expect_error(aqt_hmm_simulate_truth(sampling_dt_s=0),"positive finite seconds")
 expect_error(aqt_hmm_simulate_truth(sampling_dt_s=Inf),"positive finite seconds")
 expect_error(aqt_hmm_simulate_truth(n_tanks=101),"outside supported")
 expect_error(aqt_hmm_simulate_truth(n_samples=5001),"outside supported")
})
test_that("conditional truth recovery rejects forged labels and missing simulation provenance",{
 s<-aqt_hmm_simulate_truth(n_tanks=4,fish_per_tank=1,n_samples=14,
                    state_means=c(0,8),state_sds=c(.5,.5),seed=25)
 wrong<-s
 attr(wrong,"aqt_truth_model")<-NULL
 expect_error(aqt_hmm_recovery_audit(wrong,c("T001","T002")),
              "Synthetic truth metadata required")
 bad<-s
 attr(bad,"aqt_truth_model")$synthetic_only<-FALSE
 expect_error(aqt_hmm_recovery_audit(bad,c("T001","T002")),
              "Synthetic truth metadata required")
 bad<-s
 bad$truth_state[bad$tank_id %in% c("T003","T004")]<-NA_integer_
 expect_error(aqt_hmm_recovery_audit(bad,c("T001","T002"),
       max_iter=20),"Heldout latent truth labels")
 bad<-s
 bad$truth_state[bad$tank_id %in% c("T003","T004")]<-3L
 expect_error(aqt_hmm_recovery_audit(bad,c("T001","T002"),
       max_iter=20),"Heldout latent truth labels")
})
