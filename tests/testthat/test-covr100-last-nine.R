# Entirely synthetic scientific failure fixtures.
test_that("joint-tank sensitivity refuses nonfinite estimator outputs",{
 scenario <- structure(list(tracks=list(
    data.frame(tank_id="C1",treatment="control"))),
    class="aqt_joint_refractive_scenarios")
 events <- data.frame(session_id="S",event_id="E",start_s=0,end_s=0)
 testthat::with_mocked_bindings({
   expect_error(aqt_joint_tank_sensitivity(scenario,events),
                "Nonfinite treatment contrasts")
 },aqt_joint_event_sensitivity=function(...) data.frame(draw=1L),
   aqt_tank_event_contrast=function(...) list(
      estimate=Inf,lower=Inf,upper=Inf,
      n_tanks_control=2L,n_tanks_treatment=2L),
   .package="aquaTrajectories")
})
test_that("scope collisions cannot create cross-recording motion in image QC",{
 frames <- data.frame(
   session_id=c("A\rB","A"),camera_id=c("C","B\rC"),
   frame_id=c(0,1),time_s=c(0,.2),
   width_px=c(100,100),height_px=c(100,100))
 raw <- data.frame(
   session_id=frames$session_id,camera_id=frames$camera_id,
   track_id=c("F","F"),frame_id=frames$frame_id,
   time_s=frames$time_s,x=c(10,30),y=c(10,10),
   observed=TRUE,detection_confidence=c(.9,.9))
 audited <- aqt_trajectory_qc(raw,frames,max_gap_s=.25)
 expect_s3_class(audited,"aqt_trajectory_qc")
 expect_true(all(is.na(audited$row_audit$step_distance)))
 expect_true(all(is.na(audited$row_audit$step_dt_s)))
})
