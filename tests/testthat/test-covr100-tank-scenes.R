# 3D tank storyboard and projection tests use supplied physical XYZ only.
.cov100_scene_tracks <- function() {
 aqt_tracks(data.frame(session_id="S",camera_id="FUSED",
       track_id=rep(c("A","B"),each=4),
       time_s=rep(0:3,2),x=c(0:3,2:5),
       y=c(0:3,rep(4,4)),z=c(0:3,rep(2,4)),
       observed=TRUE),units="cm",coordinate_system="tank")
}
test_that("physical 3D scene rejects unscoped tracks, invalid clocks and negative time limits",{
 tr <- .cov100_scene_tracks()
 expect_error(aqt_tank_scene_snapshot(tr,frame_s=NA_real_),
              "times must be finite numeric scalars")
 expect_error(aqt_tank_scene_snapshot(tr,frame_s=Inf),
              "times must be finite numeric scalars")
 expect_error(aqt_tank_scene_snapshot(tr,frame_s=1,tail_s=-1),
              "tail_s and max_age_s must")
 expect_error(aqt_tank_scene_snapshot(tr,frame_s=1,max_age_s=-.1),
              "tail_s and max_age_s must")
 expect_error(aqt_tank_scene_snapshot(tr,frame_s=1,max_gap_s=0),
              "tail_s and max_age_s must")
 expect_error(aqt_tank_scene_snapshot(tr,frame_s=1,max_gap_s=-1),
              "tail_s and max_age_s must")
 expect_error(aqt_tank_scene_storyboard(tr,numeric(0)),
              "1..200 strictly increasing")
 expect_error(aqt_tank_scene_storyboard(tr,c(1,1)),
              "1..200 strictly increasing")
 expect_error(aqt_tank_scene_storyboard(tr,seq_len(201)),
              "1..200 strictly increasing")
 nonphysical <- as.data.frame(tr);nonphysical$z <- NULL
 expect_error(aqt_tank_scene_snapshot(aqt_tracks(nonphysical),1),
              "measured physical XYZ")
 many <- as.data.frame(tr);many$session_id <- "S2"
 duplicate <- aqt_tracks(rbind(as.data.frame(tr),many),
                 units="cm",coordinate_system="tank")
 expect_error(aqt_tank_scene_snapshot(duplicate,1),
              "one session and one fused")
})
test_that("physical scenes never reuse a fish after an explicitly missing final observation",{
 tr <- .cov100_scene_tracks()
 event <- data.frame(session_id="S",event_id="E",start_s=1,end_s=2)
 at_one <- aqt_tank_scene_snapshot(tr,frame_s=1,tail_s=2,
              max_age_s=.25,max_gap_s=1.1,events=event)
 expect_s3_class(at_one,"aqt_tank_scene")
 expect_equal(at_one$n_visible,2L)
 expect_identical(at_one$active_events,"E")
 expect_true(nrow(at_one$tails)>0L)
 grDevices::pdf(tempfile(fileext=".pdf"))
 on.exit(grDevices::dev.off(),add=TRUE)
 expect_invisible(aqt_plot_tank_projection(at_one,plane="xy"))
 expect_invisible(aqt_plot_tank_projection(at_one,plane="xz"))
 expect_invisible(aqt_plot_tank_projection(at_one,plane="yz"))
 expect_error(aqt_plot_tank_projection(list()),"Expected aqt_tank_scene")
 absent <- aqt_tank_scene_snapshot(tr,frame_s=100,max_age_s=.1)
 expect_equal(absent$n_visible,0L)
 expect_error(aqt_plot_tank_projection(absent),
              "No verified fish positions")
 s <- aqt_tank_scene_storyboard(tr,c(0,1,2,3),
                 max_age_s=.1,max_gap_s=1.1,events=event)
 expect_s3_class(s,"aqt_tank_storyboard")
 expect_equal(length(s),4L)
 bad <- as.data.frame(tr)
 bad$observed[bad$track_id=="B" & bad$time_s==2] <- FALSE
 bad$x[bad$track_id=="B" & bad$time_s==2] <- NA_real_
 bad$y[bad$track_id=="B" & bad$time_s==2] <- NA_real_
 bad$z[bad$track_id=="B" & bad$time_s==2] <- NA_real_
 skipped <- aqt_tank_scene_snapshot(aqt_tracks(bad,
                  units="cm",coordinate_system="tank"),2,
                  max_age_s=2,max_gap_s=1.1)
 expect_equal(skipped$n_visible,1L)
 expect_false("B" %in% skipped$heads$track_id)
 expect_false(skipped$calibration_certified)
})
test_that("tank scene constant-axis projections expand rather than collapsing scientific scale",{
 d <- as.data.frame(.cov100_scene_tracks())
 d$x[] <- 2;d$y[] <- 3;d$z[] <- 4
 tr <- aqt_tracks(d,units="cm",coordinate_system="tank")
 at <- aqt_tank_scene_snapshot(tr,frame_s=3,max_age_s=0)
 grDevices::pdf(tempfile(fileext=".pdf"))
 on.exit(grDevices::dev.off(),add=TRUE)
 expect_invisible(aqt_plot_tank_projection(at,plane="xy"))
 expect_invisible(aqt_plot_tank_projection(at,plane="xz"))
 expect_invisible(aqt_plot_tank_projection(at,plane="yz"))
 if(requireNamespace("rgl",quietly=TRUE)) {
   options(rgl.useNULL=TRUE)
   expect_error(aqt_plot_tank_scene3d(
         aqt_tank_scene_snapshot(tr,frame_s=100,max_age_s=0)),
         "No verified fish positions")
 }
});
