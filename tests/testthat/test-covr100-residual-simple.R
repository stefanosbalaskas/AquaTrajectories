# Residual scientifically meaningful empty-source and provenance cases.
# All records are synthetic; no fish identity or physical calibration certified.
.cov100_residual_xyz <- function() {
 d <- data.frame(session_id="S",camera_id="FUSED",
       track_id="A",time_s=c(0,.1,.2),
       x=c(1,2,3),y=c(0,0,0),z=c(2,2,2),
       observed=TRUE)
 aqt_tracks(d,units="cm",coordinate_system="tank")
}
test_that("empty canonical paths and occupancy keep exact zero denominators",{
 tr <- .cov100_residual_xyz()
 empty <- aqt_tracks(as.data.frame(tr)[FALSE,,drop=FALSE],
                   units="cm",coordinate_system="tank")
 zones <- data.frame(zone_id="zone",xmin=0,xmax=5,
                     ymin=-1,ymax=1)
 out <- aqt_zone_occupancy(empty,zones)
 expect_equal(nrow(out),0L)
 expect_identical(names(out),character(0))
 expect_error(aqt_trajectory_dtw_matrix(empty),"No trajectories to compare")
})
test_that("source fish_id CSV identifiers remain strings in YOLO importer", {
 dir <- tempfile("cov100_fishid_",fileext=".csv")
 on.exit(unlink(dir),add=TRUE)
 d <- data.frame(fish_id=c("0004","0004"),x_px=c(10,11),
                 y_px=c(20,20),time_s=c(0,.1))
 utils::write.csv(d,dir,row.names=FALSE,quote=TRUE)
 tracks <- aqt_import_yolo(dir,session_id="S",camera_id="C")
 expect_identical(as.character(tracks$track_id),c("0004","0004"))
 expect_equal(tracks$x,c(10,11))
 expect_equal(tracks$time_s,c(0,.1))
})
test_that("scene tail shorter than latest observed age is visibly empty, not reused",{
 tr <- .cov100_residual_xyz()
 snap <- aqt_tank_scene_snapshot(tr,frame_s=.25,tail_s=.01,
                    max_age_s=.1,max_gap_s=.11)
 expect_equal(snap$n_visible,1L)
 expect_equal(nrow(snap$heads),1L)
 expect_equal(nrow(snap$tails),0L)
 expect_false(snap$calibration_certified)
})
test_that("group voxel drawing accepts absent optional fish-ID column without fabricating fish",{
 if(!requireNamespace("rgl",quietly=TRUE))skip("rgl is optional")
 options(rgl.useNULL=TRUE)
 tr <- .cov100_residual_xyz()
 breaks <- list(x=c(0,2,4),y=c(-1,1),z=c(1,3))
 v <- aqt_voxel_occupancy(tr,breaks,by="group")
 v$track_id <- NULL
 expect_false("track_id" %in% names(v))
 out <- aqt_plot_voxel3d(v)
 expect_true(nrow(out)>0)
 expect_true(all(out$n_samples>0))
 rgl::close3d()
})
test_that("tank change plotting refuses a dataset with no finite eligible values",{
 expect_error(aqt_plot_tank_changes(list()),"Expected an aqt_tank_event_contrast")
 blank <- list(per_tank=data.frame(
    tank_id=c("T1","T2"),treatment=c("A","B"),
    mean_baseline=c(NA_real_,NA_real_),
    mean_response=c(NA_real_,NA_real_)),
    treatment_levels=c("A","B"))
 expect_error(aqt_plot_tank_changes(blank),"No finite tank observations")
})
test_that("publication number and scope helpers diagnose missing input explicitly",{
 expect_error(aquaTrajectories:::.aqt_pub_number(NA_real_,
               "value",finite=FALSE),
              "value must be a numeric scalar")
 expect_error(aquaTrajectories:::.aqt_pub_scope(
               data.frame(condition=c("A"," ")),"condition"),
              "Missing or blank condition labels")
})
