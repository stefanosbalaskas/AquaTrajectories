# Source-grounded residual edge cases: no new empirical fish observations.
.cov100_edge_path <- function(n=2) {
 aqt_tracks(data.frame(session_id="S",camera_id="C",
    track_id="F",time_s=seq_len(n)-1L,x=seq_len(n),
    y=rep(0,n),observed=TRUE),
    units="cm",coordinate_system="tank")
}
test_that("single observed sample cannot masquerade as a DTW path",{
 path <- .cov100_edge_path(1)
 expect_error(aquaTrajectories:::.aqt_single_path(path),
              "Insufficient observed trajectory samples")
})
test_that("class-agnostic and class-aware IDF1 are explicitly different estimands",{
 gt <- data.frame(session_id="S",camera_id="C",frame_id=0:2,
  track_id="A",x=0:2,y=0,class_id="fish")
 pd <- gt
 pd$track_id <- "B"
 pd$class_id <- "unknown"
 aware <- aqt_tracking_metrics(gt,pd,max_distance=.1,class_aware=TRUE)
 agnostic <- aqt_tracking_metrics(gt,pd,max_distance=.1,class_aware=FALSE)
 expect_equal(aware$n_matches,0L)
 expect_equal(agnostic$n_matches,3L)
 expect_equal(agnostic$IDF1,1)
 expect_equal(aware$IDF1,0)
})
test_that("MOT importer does not treat a missing file as a valid empty video",{
 frames <- aqt_frame_manifest(data.frame(
  session_id="S",camera_id="C",frame_id=0:1,
  time_s=c(0,.1),width_px=c(64,64),height_px=c(48,48)))
 expect_error(aqt_import_mot(tempfile(fileext=".txt"),
      frames,session_id="S",camera_id="C"),"MOT text path does not exist")
})
test_that("storyboard camera selector is genuinely scoped and preserves empty selection",{
 tr <- aqt_tracks(data.frame(session_id="S",camera_id="C",
  track_id="F",time_s=0:4,x=0:4,y=0:4,z=0:4,observed=TRUE),
  units="cm",coordinate_system="tank")
 expect_error(aqt_plot_trajectory_storyboard3d(tr,camera_id="UNRECORDED"),
              "Selected 3D fish scope contains no records")
})
