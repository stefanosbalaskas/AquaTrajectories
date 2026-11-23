# Internal research-model guard tests use synthetic sources, preserving
# the original review units and the distinction between fish and tank units.
.cov100_ens_tracks <- function(n=4L,three=FALSE) {
 d <- data.frame(session_id="S",camera_id="TOP",
      track_id=rep(c("A","B"),each=n),time_s=rep(seq_len(n)-1L,2),
      x=c(seq_len(n),seq_len(n)+3),y=rep(0,2*n),
      observed=TRUE)
 if(three)d$z <- c(seq_len(n)*.5,seq_len(n)*.5+3)
 aqt_tracks(d,units="cm",coordinate_system="tank")
}
.cov100_ens_config <- function() list(
 max_gap_s=1.1,
 uncertainty=list(sigma=.1,rho=0,systematic_sd=0,
                  draws=20L,seed=11L,enabled=TRUE))
test_that("research conditional sensitivity refuses no observed movements and exceeded memory",{
 model <- aquaTrajectories:::.aqt_research_ensemble
 tr <- .cov100_ens_tracks()
 kin <- aqt_kinematics(tr,max_gap_s=1.1)
 missing <- kin
 missing$step_distance[] <- NA_real_
 expect_error(model(list(tracks=tr),list(kinematics=missing),
         .cov100_ens_config()),"No eligible movement intervals")
 synthetic_oversize <- data.frame(x=rep(1,1001L))
 expect_error(model(list(tracks=synthetic_oversize),
       list(kinematics=kin),modifyList(.cov100_ens_config(),
       list(uncertainty=list(draws=1000L)))),
       "scenario memory guard")
})
test_that("uncertainty comparators reject a reordered but otherwise identical source ledger",{
 tr <- .cov100_ens_tracks()
 kin <- aqt_kinematics(tr,max_gap_s=1.1)
 model <- aquaTrajectories:::.aqt_research_ensemble
 shuffled <- kin[nrow(kin):1,,drop=FALSE]
 expect_error(model(list(tracks=tr),list(kinematics=shuffled),
             .cov100_ens_config()),"ledger ordering differ")
 ans <- model(list(tracks=tr),list(kinematics=kin),
             .cov100_ens_config())
 expect_equal(ans$n_scenarios,20L)
 expect_false(ans$physical_error_calibrated)
 expect_true(ans$fixed_identity)
 expect_true(all(!ans$path_sensitivity$interval_is_confidence_interval))
})
test_that("research polarization counts only simultaneous nonzero 3D headings",{
 tr <- .cov100_ens_tracks(three=TRUE)
 group <- aqt_group_metrics(tr,max_gap_s=1.1)
 kin <- aqt_kinematics(tr,max_gap_s=1.1)
 polarization <- aquaTrajectories:::.aqt_research_polarization
 got <- polarization(group,kin)
 expect_equal(nrow(got),nrow(group))
 expect_true(any(is.finite(got$polarization)))
 expect_true(all(got$polarization[is.finite(got$polarization)]>=0 &
                 got$polarization[is.finite(got$polarization)]<=1))
 empty <- polarization(group[FALSE,,drop=FALSE],kin)
 expect_equal(nrow(empty),0L)
 missing <- polarization(group,kin[FALSE,,drop=FALSE])
 expect_true(all(is.na(missing$polarization)))
 status <- aquaTrajectories:::.aqt_research_notes(
     "blocked","No valid source-PTS relationship",0L)
 expect_identical(status$status,"blocked")
})
