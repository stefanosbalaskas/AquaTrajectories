# Synthetic numerical guard tests. No physical calibration or empirical fish
# inference is claimed by these edge-condition checks.
test_that("reconstruction QC refuses to graph entirely unobserved stereo estimates", {
  xyz <- aqt_simulate_tracks(n_fish=1L,n_frames=6L,
                            dimension=3L,seed=901L)
  xyz$observed[] <- FALSE
  xyz$reprojection_rmse_px <- rep(NA_real_,nrow(xyz))
  xyz$time_skew_s <- rep(0,nrow(xyz))
  expect_invisible(aqt_tracks_validate(xyz))
  quality <- aqt_reconstruction_quality(xyz)
  expect_equal(quality$n_reconstructed,0L)
  expect_equal(quality$missing_fraction,1)
  expect_true(is.na(quality$median_reprojection_px))
  expect_error(aqt_plot_reconstruction_qc(xyz),
               "No valid reconstructed samples to plot")
})

test_that("paired underwater target benchmark rejects negative geometry tolerance", {
  n <- 9L
  measured <- data.frame(
    trial_id="SYN",tank_id="T1",session_id="S1",
    camera_a_id="A",camera_b_id="B",
    target_id=paste0("L",seq_len(n)),
    target_group=c(rep("FITTED",6),rep("HOLDOUT",3)),
    partition=c(rep("fit",6),rep("holdout",3)),
    truth_x=seq_len(n)/10,truth_y=seq_len(n)/20,
    truth_z=rep(1:3,3),
    a_u_px=seq_len(n)/10,a_v_px=seq_len(n)/20,
    b_u_px=seq_len(n)/10,b_v_px=seq_len(n)/20
  )
  targets <- aqt_target_trial_table(measured,units="cm")
  make_camera <- function(center)
    aqt_refractive_camera(
      K=diag(3),R_c2w=diag(3),center=center,
      plane_point=c(0,0,1),plane_normal=c(0,0,1),
      units="cm",n_before=1,n_after=1.333)
  cameras <- list(A=make_camera(c(0,0,0)),
                  B=make_camera(c(2,0,0)))
  expect_error(aqt_target_holdout_benchmark(
                 targets,cameras,max_ray_separation=-1),
               "max_ray_separation must be nonnegative")
})

test_that("joint scenario chart preserves degenerate real-valued projected axes", {
  observation <- aqt_tracks(
    data.frame(session_id="S",camera_id="FUSED",
      track_id="F",time_s=0:2,
      x=rep(1,3),y=rep(2,3),z=rep(3,3),
      observed=TRUE),units="cm",coordinate_system="tank")
  cases <- structure(list(tracks=list(observation,observation)),
                     class="aqt_joint_refractive_scenarios")
  cloud <- aqt_joint_scene_cloud(cases,"S",2,max_age_s=.1)
  expect_equal(nrow(cloud$points),2L)
  expect_equal(diff(range(cloud$points$x)),0)
  expect_equal(diff(range(cloud$points$y)),0)
  device <- tempfile(fileext=".pdf")
  grDevices::pdf(device)
  on.exit(grDevices::dev.off(),add=TRUE)
  expect_invisible(aqt_plot_joint_scene_cloud(cloud,plane="xy"))
})
