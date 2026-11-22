# Four-panel 3D storyboard audits only observed physical XYZ and externally
# declared tank bounds. No missing depth is reconstructed.
.cov100_sb_source <- function(missing=FALSE,flat=FALSE) {
 d <- data.frame(session_id="S",camera_id="C",track_id="F",
    time_s=0:5,x=if(flat)rep(2,6) else 0:5,
    y=if(flat)rep(4,6) else 0:5,
    z=if(flat)rep(1,6) else 0:5,observed=TRUE)
 if (missing) {
   d$observed[3] <- FALSE
   d$x[3] <- NA_real_;d$y[3] <- NA_real_;d$z[3] <- NA_real_
 }
 aqt_tracks(d,units="cm",coordinate_system="tank")
}
test_that("four-panel 3D storyboard fails closed on coordinates, scope and time", {
 tr <- .cov100_sb_source()
 bad <- as.data.frame(tr);bad$z <- NULL
 expect_error(aqt_plot_trajectory_storyboard3d(
       aqt_tracks(bad,units="cm",coordinate_system="tank")),
       "real physical XYZ")
 expect_error(aqt_plot_trajectory_storyboard3d(tr[FALSE,,drop=FALSE]),
              "No fish observations")
 expect_error(aqt_plot_trajectory_storyboard3d(tr,session_id=""),
              "nonempty scalar character")
 expect_error(aqt_plot_trajectory_storyboard3d(tr,camera_id=NA_character_),
              "nonempty scalar character")
 expect_error(aqt_plot_trajectory_storyboard3d(tr,track_id=1),
              "nonempty scalar character")
 expect_error(aqt_plot_trajectory_storyboard3d(tr,recent_s=0),
              "strictly positive")
 expect_error(aqt_plot_trajectory_storyboard3d(tr,max_gap_s=0),
              "strictly positive")
 expect_error(aqt_plot_trajectory_storyboard3d(tr,max_age_s=-1),
              "nonnegative numeric")
 expect_error(aqt_plot_trajectory_storyboard3d(tr,max_age_s=NA_real_),
              "nonnegative numeric")
 expect_error(aqt_plot_trajectory_storyboard3d(tr,max_gap_s=NA_real_),
              "nonnegative numeric")
 expect_error(aqt_plot_trajectory_storyboard3d(tr,recent_s=Inf),
              "strictly positive")
 expect_error(aqt_plot_trajectory_storyboard3d(tr,session_id="OTHER"),
              "no records")
 dup <- as.data.frame(tr)
 dup$track_id <- "SECOND"
 multi <- aqt_tracks(rbind(as.data.frame(tr),dup),
            units="cm",coordinate_system="tank")
 expect_error(aqt_plot_trajectory_storyboard3d(multi),
              "exactly one session/camera/track_id")
 empty <- as.data.frame(tr);empty$observed[]<-FALSE
 empty$x<-NA_real_;empty$y<-NA_real_;empty$z<-NA_real_
 expect_error(aqt_plot_trajectory_storyboard3d(aqt_tracks(empty,
              units="cm",coordinate_system="tank")),
              "No genuine observed XYZ")
 singleton <- tr[1,,drop=FALSE]
 expect_error(aqt_plot_trajectory_storyboard3d(singleton),
              "more than one timestamp")
 expect_error(aqt_plot_trajectory_storyboard3d(tr,times_s=c(0,1,2)),
              "four strictly increasing")
 expect_error(aqt_plot_trajectory_storyboard3d(tr,times_s=c(0,1,2,Inf)),
              "four strictly increasing")
 expect_error(aqt_plot_trajectory_storyboard3d(tr,times_s=c(0,1,1,3)),
              "four strictly increasing")
 expect_error(aqt_plot_trajectory_storyboard3d(tr,times_s=c(-1,1,2,3)),
              "four strictly increasing")
 expect_error(aqt_plot_trajectory_storyboard3d(tr,tank_limits=list(x=c(0,1))),
              "finite increasing x/y/z")
 expect_error(aqt_plot_trajectory_storyboard3d(tr,tank_limits=list(
                  x=c(0,5),y=c(0,5),z=c(3,1))),
              "finite increasing x/y/z")
 expect_error(aqt_plot_trajectory_storyboard3d(tr,tank_limits=list(
                  x=c(0,5),y=c(0,5),z=c(0,4))),
              "outside tank_limits: z")
})
test_that("storyboard measures distance only across contiguous genuine observations",{
 tr <- .cov100_sb_source()
 grDevices::pdf(tempfile(fileext=".pdf"),width=10,height=8)
 on.exit(grDevices::dev.off(),add=TRUE)
 fig <- aqt_plot_trajectory_storyboard3d(tr,
       times_s=c(0,1,3,5),recent_s=1,max_age_s=.2,
       tank_limits=list(x=c(-1,6),y=c(-1,6),z=c(-1,6)))
 expect_equal(nrow(fig),4)
 expect_equal(fig$observed_distance[1],0)
 expect_equal(fig$observed_distance[4],5*sqrt(3),tolerance=1e-12)
 expect_equal(fig$n_contiguous_segments,c(0,1,3,5))
 expect_true(all(fig$current_position_observed))
 expect_equal(fig$latest_segment_speed[4],sqrt(3),tolerance=1e-12)
 expect_false(attr(fig,"tank_bounds_from_observations"))
 expect_false(attr(fig,"independent_calibration_certified"))
 stopped <- aqt_plot_trajectory_storyboard3d(tr,
       times_s=c(.1,1.1,3.1,4.7),max_age_s=.05)
 expect_true(all(!stopped$current_position_observed))
 expect_true(all(is.na(stopped$latest_segment_speed)))
 missing <- .cov100_sb_source(missing=TRUE)
 sub <- aqt_plot_trajectory_storyboard3d(missing,
         times_s=c(0,1,3,5),max_gap_s=1.1)
 expect_equal(sub$n_contiguous_segments[4],3L)
 expect_equal(sub$observed_distance[4],3*sqrt(3),tolerance=1e-12)
 disconnected <- aqt_plot_trajectory_storyboard3d(tr,
        times_s=c(0,1,3,5),max_gap_s=.5)
 expect_true(all(disconnected$observed_distance==0))
 flat <- aqt_plot_trajectory_storyboard3d(.cov100_sb_source(flat=TRUE))
 expect_true(attr(flat,"tank_bounds_from_observations"))
 expect_true(all(flat$observed_distance==0))
});
