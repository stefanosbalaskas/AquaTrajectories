test_that("voxel counts and denominators are explicit and reproducible", {
  tr <- aqt_tracks(data.frame(session_id="S1",camera_id="FUSED3D",
    track_id="fish1",time_s=c(0,1,2),
    x=c(2,3,10),y=c(1,1,1),z=c(4,4,4)),
    units="cm",coordinate_system="tank")
  b <- list(x=c(0,2.5,5),y=c(0,2),z=c(0,5))
  d <- aqt_voxel_occupancy(tr,b,by="fish")
  expect_equal(d$n_samples,c(1L,1L))
  expect_equal(d$sample_fraction,c(1/3,1/3))
  expect_true(all(d$n_valid==3))
  expect_true(all(d$n_outside==1))
  expect_error(aqt_voxel_occupancy(tr,list(x=c(0,0),
    y=c(0,1),z=c(0,1))),"increasing")
  flat <- aqt_tracks(data.frame(session_id="S",camera_id="TOP",
    track_id="1",time_s=0,x=1,y=1))
  expect_error(aqt_voxel_occupancy(flat,b),"3D")
})

test_that("stereo diagnostic plotting runs on a noninteractive PDF device", {
  P1 <- cbind(diag(3),c(0,0,0))
  P2 <- cbind(diag(3),c(-1,0,0))
  rig <- aqt_rig_new(list(TOP=P1,SIDE=P2),optical_path="air_only")
  top <- aqt_tracks(data.frame(session_id="S1",camera_id="TOP",
    track_id="1",time_s=c(0,1),x=c(.5,.75),y=c(.25,.25)))
  side <- aqt_tracks(data.frame(session_id="S1",camera_id="SIDE",
    track_id="2",time_s=c(0,1),x=c(.25,.5),y=c(.25,.25)))
  pairs <- data.frame(session_id="S1",id_a="1",id_b="2",
    time_a_s=c(0,1),time_b_s=c(0,1),fish_id="A")
  xyz <- aqt_reconstruct_3d(top,side,pairs,rig)
  path <- tempfile(fileext=".pdf")
  grDevices::pdf(path)
  tryCatch({
    report <- aqt_plot_reconstruction_qc(xyz)
    expect_equal(report$n_reconstructed,2)
  },finally=grDevices::dev.off())
  expect_true(file.exists(path))
  unlink(path)
})
