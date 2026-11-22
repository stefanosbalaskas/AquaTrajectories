# Publication graphics display measured/source-eligible points only.
.cov100_viz3d <- function() {
 d <- data.frame(session_id="S",camera_id="FUSED",
     track_id=rep(c("A","B"),each=3),time_s=rep(0:2,2),
     x=c(0,1,2,4,5,6),y=c(1,1,1,3,3,3),
     z=c(rep(2,3),rep(4,3)),observed=TRUE)
 aqt_tracks(d,units="cm",coordinate_system="tank")
}
.cov100_use_null_rgl <- function() {
 if (!requireNamespace("rgl",quietly=TRUE))testthat::skip("Optional rgl unavailable")
 options(rgl.useNULL=TRUE)
 rgl::rgl.useNULL(TRUE)
}
test_that("2D conditional scenario plots enforce scope and stable graphic bounds",{
 source <- as.data.frame(.cov100_viz3d())
 source$z <- NULL
 tr <- aqt_tracks(source,units="cm",coordinate_system="tank")
 en <- aqt_trajectory_ensemble(tr,draws=20,seed=11,sigma=.1,max_gap_s=1.1)
 expect_error(aqt_plot_ensemble2d(list(),"S","FUSED","A"),
              "Expected aqt_trajectory_ensemble")
 expect_error(aqt_plot_ensemble2d(en,"S","FUSED","A",n_draws=0),
              "integer from 1 to 60")
 expect_error(aqt_plot_ensemble2d(en,"S","FUSED","A",n_draws=61),
              "integer from 1 to 60")
 expect_error(aqt_plot_ensemble2d(en,"S","FUSED","A",n_draws=1.5),
              "integer from 1 to 60")
 expect_error(aqt_plot_ensemble2d(en,"S","FUSED","absent"),
              "No fish track in requested scope")
 broken <- en
 broken$positions[] <- NA_real_
 broken$tracks$x <- NA_real_;broken$tracks$y <- NA_real_
 expect_error(aqt_plot_ensemble2d(broken,"S","FUSED","A"),
              "No valid positions")
 constant <- as.data.frame(tr)
 constant$x <- 1;constant$y <- 2
 fixed <- aqt_tracks(constant,units="cm",coordinate_system="tank")
 zero <- aqt_trajectory_ensemble(fixed,draws=20,seed=11,sigma=0)
 grDevices::pdf(tempfile(fileext=".pdf"))
 on.exit(grDevices::dev.off(),add=TRUE)
 expect_length(aqt_plot_ensemble2d(zero,"S","FUSED","A",n_draws=1),3L)
 expect_length(aqt_plot_ensemble2d(en,"S","FUSED","A",n_draws=20),3L)
})
test_that("observed XY plots split missing periods and reject empty source positions",{
 source <- as.data.frame(.cov100_viz3d())
 source$z <- NULL
 tr <- aqt_tracks(source,units="px",coordinate_system="image")
 expect_error(aqt_plot_paths(tr,max_gap_s=0),"max_gap_s must")
 blank <- tr[FALSE,,drop=FALSE]
 expect_error(aqt_plot_paths(blank),"No valid positions")
 missing <- as.data.frame(tr)
 missing$observed <- FALSE
 no_observed <- aqt_tracks(missing,units="px",coordinate_system="image")
 expect_error(aqt_plot_paths(no_observed),"No valid positions")
 expect_equal(length(aquaTrajectories:::.aqt_observed_path_runs(
      missing[FALSE,,drop=FALSE])),0L)
 grDevices::pdf(tempfile(fileext=".pdf"))
 on.exit(grDevices::dev.off(),add=TRUE)
 expect_invisible(aqt_plot_paths(tr,max_gap_s=.6))
 single <- tr[tr$time_s==1,,drop=FALSE]
 expect_invisible(aqt_plot_paths(single))
})
test_that("pinhole triangulation rejects degenerate matrices and invalid rays",{
 pa <- cbind(diag(3),c(0,0,0))
 pb <- cbind(diag(3),c(-2,0,0))
 a <- matrix(c(0,0),ncol=2)
 b <- matrix(c(-.4,0),ncol=2)
 expect_error(aqt_triangulate_pairs(a,matrix(1:4,ncol=2),pa,pb),
              "matched n-by-2")
 expect_error(aqt_triangulate_pairs(a,b,diag(3),pb),
              "finite 3-by-4")
 bad <- pb;bad[1,1] <- Inf
 expect_error(aqt_triangulate_pairs(a,b,pa,bad),
              "finite 3-by-4")
 correct <- aqt_triangulate_pairs(a,b,pa,pb)
 expect_equal(correct$z,5,tolerance=1e-8)
 expect_equal(correct$reprojection_rmse,0,tolerance=1e-9)
 invalid <- aqt_triangulate_pairs(matrix(c(NA,0),ncol=2),b,pa,pb)
 expect_false(invalid$valid)
 parallel <- aqt_triangulate_pairs(a,a,pa,pa)
 expect_false(parallel$valid)
})
test_that("3D rgl path and schooling graphics respect physical views and singleton frames",{
 .cov100_use_null_rgl()
 tr <- .cov100_viz3d()
 expect_error(aqt_plot_path3d(tr,max_gap_s=0),"max_gap_s")
 unobserved <- as.data.frame(tr);unobserved$observed <- FALSE
 expect_error(aqt_plot_path3d(aqt_tracks(unobserved,units="cm",
              coordinate_system="tank")),"No observed 3D")
 expect_error(aqt_plot_school3d(tr,"S","FUSED",time_s=Inf),
              "one finite timestamp")
 expect_error(aqt_plot_school3d(tr,"S","FUSED",time_s=1,label_ids=NA),
              "label_ids must")
 expect_error(aqt_plot_school3d(tr,"S","FUSED",time_s=101),
              "No observed fish")
 expected <- aqt_plot_school3d(tr,"S","FUSED",time_s=1,label_ids=FALSE)
 expect_equal(nrow(expected),2L)
 expect_equal(nrow(aqt_plot_school3d(tr,"S","FUSED",time_s=1,
              label_ids=TRUE)),2L)
 one <- tr[tr$time_s==1,,drop=FALSE]
 expect_invisible(aqt_plot_path3d(one,max_gap_s=.2))
 expect_invisible(aqt_plot_path3d(tr,max_gap_s=1.1))
 rgl::close3d()
})
test_that("3D voxel visualization refuses missing or mismatched groups",{
 .cov100_use_null_rgl()
 tr <- .cov100_viz3d()
 v <- aqt_voxel_occupancy(tr,list(x=c(-1,4,9),y=c(0,2,5),
                               z=c(0,3,6)),by="group")
 expect_error(aqt_plot_voxel3d(data.frame()),"Expected nonempty")
 bad <- v;bad$n_samples <- -1
 expect_error(aqt_plot_voxel3d(bad),"Invalid voxel sample counts")
 bad <- v;bad$track_id[1] <- "B"
 expect_error(aqt_plot_voxel3d(bad),"one session/camera/fish")
 bad <- v;bad$n_samples <- 0
 expect_error(aqt_plot_voxel3d(bad),"No occupied voxels")
 bad <- v;bad$sample_fraction[bad$n_samples>0][1] <- Inf
 expect_error(aqt_plot_voxel3d(bad),"Invalid occupied voxel")
 bad <- v;bad$x_mid[bad$n_samples>0][1] <- Inf
 expect_error(aqt_plot_voxel3d(bad),"Invalid occupied voxel")
 expect_gt(nrow(aqt_plot_voxel3d(v)),0)
 rgl::close3d()
})
test_that("3D conditional trajectory plot does not infer identity or calibrated intervals",{
 .cov100_use_null_rgl()
 tr <- .cov100_viz3d()
 en <- aqt_trajectory_ensemble(tr,draws=20,seed=32,sigma=.1,
                               max_gap_s=1.1)
 expect_error(aqt_plot_ensemble3d(list(),"S","FUSED","A"),
              "Requires a 3D")
 expect_error(aqt_plot_ensemble3d(en,"S","FUSED","A",n_draws=0),
              "integer from 1 to 30")
 expect_error(aqt_plot_ensemble3d(en,"S","FUSED","A",n_draws=31),
              "integer from 1 to 30")
 expect_error(aqt_plot_ensemble3d(en,"S","FUSED","missing"),
              "Unknown scoped fish")
 expect_equal(length(aqt_plot_ensemble3d(en,"S","FUSED","A",n_draws=2)),3L)
 rgl::close3d()
})
test_that("descriptive school geometry plot rejects inconsistent original units",{
 tr <- .cov100_viz3d()
 summary <- aqt_group_spatial_summary(tr)
 expect_error(aqt_plot_school_dynamics(data.frame(),"S","FUSED"),
              "Expected valid school")
 expect_error(aqt_plot_school_dynamics(summary,"notS","FUSED"),
              "No observations")
 bad <- summary;bad$mean_pair_distance <- as.character(bad$mean_pair_distance)
 expect_error(aqt_plot_school_dynamics(bad,"S","FUSED",
              metric="mean_pair_distance"),"Invalid school geometry metric")
 plain <- as.data.frame(summary)
 attr(plain,"aqt_units") <- NULL
 grDevices::pdf(tempfile(fileext=".pdf"))
 on.exit(grDevices::dev.off(),add=TRUE)
 expect_invisible(aqt_plot_school_dynamics(plain,"S","FUSED"))
 expect_invisible(aqt_plot_school_dynamics(summary,"S","FUSED",
              metric="group_extent"))
})
