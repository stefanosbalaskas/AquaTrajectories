.aqt_stereo_workflow_fixture <- function() {
  n <- 18L
  xyz <- cbind(seq(-.2,.8,length.out=n),
               .25*sin(seq_len(n)*1.3),
               seq(.5,1.9,length.out=n))
  make_cam <- function(cx) aqt_flatport_camera(
    diag(3),diag(3),center=c(cx,0,-1),
    glass_front_point=c(0,0,0),glass_normal=c(0,0,1),
    glass_thickness=.1,n_first=1,n_glass=1,
    n_water=1,units="cm")
  pixels <- function(cx) cbind((xyz[,1]-cx)/(xyz[,3]+1),
                                xyz[,2]/(xyz[,3]+1))
  a <- pixels(-1); b <- pixels(1)
  targets <- data.frame(
    trial_id="A",tank_id="tank1",session_id="S_A",
    camera_a_id="TOP",camera_b_id="SIDE",
    target_id=paste0("L",seq_len(n)),
    target_group=c(rep("BOARD_FIT",12),rep("BOARD_HOLDOUT",6)),
    partition=c(rep("fit",12),rep("holdout",6)),
    truth_x=xyz[,1],truth_y=xyz[,2],truth_z=xyz[,3],
    a_u_px=a[,1],a_v_px=a[,2],
    b_u_px=b[,1],b_v_px=b[,2])
  pulses <- c("A","B","C","D","E","F")
  t <- as.numeric(0:5)
  markers <- rbind(
    data.frame(session_id="S_A",camera_id="TOP",
               marker_id=pulses,time_s=t),
    data.frame(session_id="S_A",camera_id="SIDE",
               marker_id=pulses,time_s=(t-.02)/1.001))
  list(targets=targets,markers=markers,
       cameras=list(TOP=make_cam(-1),SIDE=make_cam(1)))
}

test_that("joint multiview holdout separates implementation from physical evidence", {
  f <- .aqt_stereo_workflow_fixture()
  out <- aqt_multiview_holdout_protocol(
    f$markers,f$targets,f$cameras,
    reference_camera="TOP",train_markers=LETTERS[1:4],
    holdout_markers=LETTERS[5:6],max_holdout_error_s=.001)
  expect_s3_class(out,"aqt_multiview_holdout_protocol")
  expect_true(out$summary$software_holdout_protocol_pass)
  expect_equal(out$summary$n_sessions,1L)
  expect_equal(out$summary$n_tanks,1)
  expect_equal(out$summary$n_heldout_physical_targets,6)
  expect_lt(out$summary$heldout_xyz_rmse,1e-8)
  expect_lt(out$summary$maximum_heldout_camera_clock_error_s,1e-8)
  expect_false(out$actual_underwater_physical_accuracy_certified)
  expect_false(out$surveyed_target_positions_externally_certified)
  expect_false(out$pulse_correspondence_verified_by_independent_hardware)
  expect_false(out$cross_view_fish_identity_accuracy_certified)
})

test_that("multiview protocol requires heldout source cameras and disjoint pulses", {
  f <- .aqt_stereo_workflow_fixture()
  bad <- f$markers[!(f$markers$camera_id=="SIDE" &
                        f$markers$marker_id=="F"),,drop=FALSE]
  expect_error(aqt_multiview_holdout_protocol(
    bad,f$targets,f$cameras,"TOP",LETTERS[1:4],LETTERS[5:6]),
    "missing a required")
  expect_error(aqt_multiview_holdout_protocol(
    f$markers,f$targets,f$cameras,"TOP",LETTERS[1:4],LETTERS[4:5]),
    "disjoint heldout")
  expect_error(aqt_multiview_holdout_protocol(
    f$markers,f$targets,list(TOP=f$cameras$TOP),"TOP",
    LETTERS[1:4],LETTERS[5:6]),
    "refractive camera models")
})
