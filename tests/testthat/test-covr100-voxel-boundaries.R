# Volume occupancy counts are sampled positions, not fish residence time.
.cov100_voxel_tracks <- function() {
 d <- data.frame(session_id="S",camera_id="FUSED",track_id="A",
    time_s=0:4,x=c(.1,.9,1.1,2.1,NA_real_),
    y=c(.1,.9,1.1,.1,NA_real_),
    z=c(.1,.9,1.1,.1,NA_real_),
    observed=c(TRUE,TRUE,TRUE,TRUE,FALSE))
 aqt_tracks(d,units="cm",coordinate_system="tank")
}
.cov100_voxel_breaks <- function() list(x=c(0,1,2),y=c(0,1,2),z=c(0,1,2))
test_that("volume occupancy validates physical XYZ, grid limits and dimension labels",{
 tr <- .cov100_voxel_tracks(); breaks <- .cov100_voxel_breaks()
 bad <- as.data.frame(tr);bad$z <- NULL
 expect_error(aqt_voxel_occupancy(aqt_tracks(bad),breaks),
              "calibrated 3D tank coordinates")
 expect_error(aqt_voxel_occupancy(tr,list(x=c(0,1))),
              "named x/y/z")
 expect_error(aqt_voxel_occupancy(tr,modifyList(breaks,
        list(x=c(1,0)))),"strictly increasing")
 expect_error(aqt_voxel_occupancy(tr,modifyList(breaks,
        list(z=c(0,NA_real_)))),"strictly increasing")
 huge <- list(x=seq_len(102),y=seq_len(102),z=seq_len(102))
 expect_error(aqt_voxel_occupancy(tr,huge),"1,000,000 cells")
 group <- aqt_voxel_occupancy(tr,breaks,by="group")
 expect_equal(nrow(group),8L)
 expect_equal(unique(group$n_valid),4L)
 expect_equal(unique(group$n_outside),1L)
 expect_equal(sum(group$n_samples),3L)
 expect_equal(sum(group$sample_fraction),3/4,tolerance=1e-12)
 expect_identical(attr(group,"aqt_units"),"cm")
 d <- as.data.frame(tr)
 d$track_id[3:5] <- "B"
 fish <- aqt_voxel_occupancy(aqt_tracks(d,units="cm",
             coordinate_system="tank"),breaks,by="fish")
 expect_equal(length(unique(fish$track_id)),2L)
 expect_equal(nrow(fish),16L)
 empty <- tr[FALSE,,drop=FALSE]
 attr(empty,"aqt_dimension") <- 3L
 expect_equal(nrow(aqt_voxel_occupancy(empty,breaks)),0L)
 no_obs <- as.data.frame(tr)
 no_obs$x <- NA_real_;no_obs$y <- NA_real_
 no_obs$observed <- FALSE
 no <- aqt_voxel_occupancy(aqt_tracks(no_obs,units="cm",
                coordinate_system="tank"),breaks)
 expect_equal(unique(no$n_valid),0L)
 expect_true(all(is.na(no$sample_fraction)))
})
test_that("voxel-reconstruction diagnostic does not assert calibration truth",{
 tr <- .cov100_voxel_tracks()
 expect_error(aqt_plot_reconstruction_qc(tr),"reprojection|reconstruction")
})
