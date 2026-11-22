# Mathematical and conditional error-model contracts, not fish accuracy.
.cov100_kin_fixture <- function(n=5,three=FALSE) {
 d <- data.frame(session_id="S",camera_id="C",track_id="A",
    time_s=seq_len(n)-1,x=seq_len(n)-1,y=rep(0,n),observed=TRUE)
 if(three)d$z <- rep(0,n)
 aqt_tracks(d,units="cm",coordinate_system="tank")
}
test_that("zero-row movement and group kinematics keep explicit empty denominators", {
 empty <- .cov100_kin_fixture(5)[0,,drop=FALSE]
 expect_equal(nrow(aqt_kinematics(empty)),0)
 expect_equal(nrow(aqt_path_summary(empty)),0)
 expect_equal(nrow(aqt_group_metrics(empty)),0)
 expect_error(aqt_track_qc(empty,max_gap_s=0),"max_gap_s must")
 expect_error(aqt_track_qc(empty,max_speed=-1,max_gap_s=1),"max_speed must")
 expect_error(aqt_track_qc(empty,max_gap_s=Inf),"max_gap_s must")
 tr <- .cov100_kin_fixture(5)
 expect_equal(aqt_path_summary(tr)$path_length,4)
 expect_equal(aqt_path_summary(tr)$mean_speed,1,tolerance=1e-12)
 qc <- aqt_track_qc(tr,max_gap_s=.8,max_speed=.2)
 expect_equal(sum(qc$large_gap),4)
 expect_equal(sum(qc$implausible_speed),4)
 blank <- as.data.frame(tr);blank$observed[] <- FALSE
 blank$x[] <- NA_real_;blank$y[] <- NA_real_
 no_observed <- aqt_tracks(blank,units="cm",coordinate_system="tank")
 group <- aqt_group_metrics(no_observed)
 expect_equal(group$n_visible,rep(0L,5))
 expect_true(all(is.na(group$centroid_x)))
 expect_true(all(is.na(group$mean_nearest_neighbor)))
 expect_true(all(is.na(group$polarization)))
})
test_that("scenario memory budget and absent RNG state are checked before sampling",{
 tr <- .cov100_kin_fixture()
 expect_error(aqt_trajectory_ensemble(tr,draws=0),"draws must")
 expect_error(aqt_trajectory_ensemble(tr,draws=20,seed=-1),"seed must")
 expect_error(aqt_trajectory_ensemble(tr,draws=20,sigma=-1),"nonnegative SD")
 expect_error(aqt_trajectory_ensemble(tr,draws=20,max_gap_s=0),"max_gap_s")
 big <- .cov100_kin_fixture(2001)
 expect_error(aqt_trajectory_ensemble(big,draws=1000L),
              "Scenario array too large")
 expect_error(aqt_detection_dropout_scenarios(big,p_missing=.2,
              draws=200L),"Dropout scenario budget exceeded")
 empty <- tr[FALSE,,drop=FALSE]
 expect_error(aqt_detection_dropout_scenarios(empty,p_missing=.2),
              "Cannot assess dropout on empty fish tracks")
 expect_error(aqt_detection_dropout_scenarios(tr,p_missing=-.1),
              "Invalid p_missing")
 expect_error(aqt_detection_dropout_scenarios(tr,p_missing=.1,draws=2.2),
              "draws/seed must be integers")
 expect_error(aqt_detection_dropout_scenarios(tr,p_missing=.1,seed=2.5),
              "draws/seed must be integers")
 expect_error(aqt_detection_dropout_scenarios(tr,p_missing=.1,
              persistence=1),"Invalid persistence")
 had <- exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE)
 if(had) prior <- get(".Random.seed",envir=.GlobalEnv)
 on.exit({
    if(had)assign(".Random.seed",prior,envir=.GlobalEnv)
    else if(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
      rm(".Random.seed",envir=.GlobalEnv)
 },add=TRUE)
 if(had)rm(".Random.seed",envir=.GlobalEnv)
 e <- aqt_trajectory_ensemble(tr,draws=20,seed=5,sigma=0)
 expect_false(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
 expect_equal(e$positions[,1,1],tr$x)
 d <- aqt_detection_dropout_scenarios(tr,p_missing=0,draws=2,seed=5)
 expect_false(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
 expect_equal(d$coverage$additional_missed,c(0,0))
 expect_false(d$assumptions$interval_coverage_calibrated)
})
test_that("descriptive scenario path summaries retain empty source and observed rows",{
 tr <- .cov100_kin_fixture()
 bad <- as.data.frame(tr)
 bad$observed[] <- FALSE;bad$x[] <- NA_real_;bad$y[] <- NA_real_
 empty_positions <- aqt_tracks(bad,units="cm",coordinate_system="tank")
 sc <- aqt_trajectory_ensemble(empty_positions,draws=20,seed=14)
 expected <- aqt_ensemble_path_summary(sc)
 expect_equal(nrow(expected),20)
 expect_true(all(is.na(expected$mean_speed)))
 expect_true(all(expected$valid_steps==0))
 zero <- .cov100_kin_fixture()[0,,drop=FALSE]
 sc0 <- aqt_trajectory_ensemble(zero,draws=20,seed=14)
 expect_equal(nrow(aqt_ensemble_path_summary(sc0)),0L)
 expect_error(aqt_detection_event_sensitivity(list(),data.frame()),
              "Expected detection dropout scenarios")
 dropout <- aqt_detection_dropout_scenarios(tr,p_missing=1,
            draws=1,seed=15)
 ev <- data.frame(session_id="S",event_id="E",start_s=2,end_s=2)
 expect_error(aqt_detection_event_sensitivity(dropout,ev,
       outcome="speed",min_points=1),
       "No estimable event outcome in dropout draw")
});
