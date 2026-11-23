# Joint optical scenarios are sensitivity assumptions, never calibrated
# posterior probabilities or human-reviewed biological identities.
.cov100_joint_input <- function() {
 a <- aqt_tracks(data.frame(session_id="S",camera_id="A",
    track_id="a",time_s=0:2,x=rep(0,3),y=0))
 b <- aqt_tracks(data.frame(session_id="S",camera_id="B",
    track_id="b",time_s=0:2,x=rep(-.4,3),y=0))
 cam <- function(x) aqt_flatport_camera(K=diag(3),R_c2w=diag(3),
    center=c(x,0,0),glass_front_point=c(0,0,1),
    glass_normal=c(0,0,1),glass_thickness=.1,
    n_first=1,n_glass=1,n_water=1,units="cm")
 match <- data.frame(session_id="S",id_a="a",id_b="b",
    time_a_s=0:2,time_b_s=0:2,fish_id="reviewed_fish")
 list(a=a,b=b,camA=cam(0),camB=cam(2),matched=match)
}
test_that("coherent joint optical sampling enforces source and physical draw contracts",{
 z <- .cov100_joint_input()
 call <- function(c1=z$camA,c2=z$camB,mat=z$matched,
                  a=z$a,b=z$b,...)
     aqt_joint_refractive_scenarios(a,b,mat,c1,c2,...)
 expect_error(call(c1=list()),"require two flatport cameras")
 expect_error(call(draws=9),"Invalid draws or ensemble")
 expect_error(call(draws=10.5),"Invalid draws or ensemble")
 expect_error(call(draws=100000),"250,000 fish positions")
 expect_error(call(seed=-1),"seed must be a valid integer")
 expect_error(call(seed=Inf),"seed must be a valid integer")
 expect_error(call(identity_events=list()),"reviewed candidate-event table")
 expect_error(call(n_glass_sd=NA_real_),"Refractive index SDs")
 expect_error(call(n_glass_sd=-1),"Refractive index SDs")
 expect_error(call(n_water_sd=Inf),"Refractive index SDs")
 expect_error(call(pixel_sd=c(1,2,3)),"nonnegative with length one or two")
 expect_error(call(center_sd=-1),"nonnegative with length one or two")
 expect_error(call(glass_thickness_sd=NA_real_),"nonnegative with length one or two")
 expect_error(call(n_glass_sd=1e9,draws=10,seed=42),
              "Invalid physical calibration draw")
 got <- call(draws=10,seed=17)
 expect_s3_class(got,"aqt_joint_refractive_scenarios")
 expect_equal(length(got$tracks),10L)
 expect_false(got$assumptions$uncertainty_interval_calibrated)
 expect_false(got$assumptions$probabilities_calibrated)
})
test_that("joint scenario event and tank analyses refuse absent observational units",{
 z <- .cov100_joint_input()
 scenarios <- aqt_joint_refractive_scenarios(
   z$a,z$b,z$matched,z$camA,z$camB,draws=10,seed=18)
 ev <- data.frame(session_id="ABSENT",event_id="E",
      start_s=1,end_s=1)
 expect_error(aqt_joint_event_sensitivity(list(),ev),
              "Expected joint refractive scenarios")
 expect_error(aqt_joint_tank_sensitivity(list(),ev),
              "Expected joint refractive scenarios")
 expect_error(aqt_joint_tank_sensitivity(scenarios,ev),
              "matched tank_id/treatment")
 expect_error(aqt_joint_event_sensitivity(scenarios,ev,
      windows=list(before=c(-1,0),after=c(0,2)),max_gap_s=1.1),
      "No estimable epochs across")
});
