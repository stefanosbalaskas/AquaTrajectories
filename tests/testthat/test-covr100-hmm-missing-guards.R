# Synthetic Gaussian-HMM transition boundaries, with no fish physiology
# or independent tank inference implied by the fitted latent states.
.cov100_no_tank_hmm <- function(fish=c("A","B"),segment_break=FALSE) {
 do.call(rbind,lapply(fish,function(id) {
    time <- if(segment_break)c(0:2,10:12) else 0:7
    data.frame(session_id="S",camera_id="C",track_id=id,
       time_s=time,speed=rep(c(.1,8),length.out=length(time)),
       observed=TRUE)
 }))
}
test_that("fixed-emission HMM rejects malformed optimizer and scope conditions",{
 d <- .cov100_no_tank_hmm()
 fun <- function(data=d,means=c(0,8),sds=c(.5,.5),
                  max_gap_s=1.1,min_segment=3,max_iter=10,...)
   aqt_hmm_transition_fit(data,state_means=means,state_sds=sds,
              max_gap_s=max_gap_s,min_segment=min_segment,
              max_iter=max_iter,...)
 expect_error(fun(means=0),"2..5 increasing")
 expect_error(fun(means=c(0,0)),"2..5 increasing")
 expect_error(fun(sds=c(1,NA_real_)),"positive and fixed")
 expect_error(fun(sds=c(.2,0)),"positive and fixed")
 expect_error(fun(max_iter=1),"integer between 2 and 2000")
 expect_error(fun(tol=0),"strictly positive")
 expect_error(fun(prior=-.1),"positive Dirichlet")
 expect_error(fun(start_transition=matrix(c(2,0,0,1),2,2)),
              "row-stochastic K-by-K")
 expect_error(fun(start_transition=matrix(.5,3,3)),
              "row-stochastic K-by-K")
 expect_error(fun(start_initial=c(.8,.8)),
              "state probability vector")
 expect_error(fun(data=.cov100_no_tank_hmm("ONLY",segment_break=TRUE)),
              ">=2 distinct scoped fish")
 fit <- fun()
 expect_s3_class(fit,"aqt_hmm_transition_fit")
 expect_false(fit$has_tank_id)
 expect_equal(length(fit$training_tanks),0L)
 expect_equal(fit$n_training_fish,2L)
 expect_false(fit$emission_parameters_estimated)
 expect_true(fit$transition_parameters_estimated)
})
test_that("HMM holdout requires declared independent tank scope, with explicit opt-out",{
 d <- .cov100_no_tank_hmm()
 fit <- aqt_hmm_transition_fit(d,state_means=c(0,8),state_sds=c(.5,.5),
   max_gap_s=1.1,min_segment=3,max_iter=10)
 held <- .cov100_no_tank_hmm("NEW")
 held$session_id <- "NEW"
 expect_error(aqt_hmm_holdout_score(held,list()),"Expected aqt_hmm_transition_fit")
 expect_error(aqt_hmm_holdout_score(held[FALSE,,drop=FALSE],fit),
              "Expected nonempty heldout")
 expect_error(aqt_hmm_holdout_score(held,fit),
              "Independent-tank holdout requires")
 expect_error(aqt_hmm_holdout_score(data.frame(x=1),fit,
              require_disjoint_tanks=FALSE),
              "Heldout fish scope fields are missing")
 expect_error(aqt_hmm_holdout_score(d,fit,require_disjoint_tanks=FALSE),
              "Heldout fish scope overlaps")
 result <- aqt_hmm_holdout_score(held,fit,require_disjoint_tanks=FALSE)
 expect_s3_class(result,"aqt_hmm_holdout_score")
 expect_true(is.finite(result$total_loglik))
 expect_false(result$independent_tank_holdout)
 expect_false(result$state_truth_certified)
 expect_false(result$calibration_certified)
})
