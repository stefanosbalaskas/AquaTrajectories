# Every joint uncertainty point is retained: no Gaussian posterior assumed.
.cov100_cloud_tracks <- function(shift=0,unit="cm",cam="FUSED",
                                assignment=FALSE) {
  d <- data.frame(session_id="S",camera_id=cam,
      track_id=rep(c("A","B"),each=3),time_s=rep(0:2,2),
      x=c(0,1,2,5,6,7)+shift,y=c(1,1,1,4,4,4),
      z=c(2,2,2,3,3,3),observed=TRUE,
      assignment_changed=assignment)
  aqt_tracks(d,units=unit,coordinate_system="tank")
}
.cov100_cloud_ensemble <- function(
  tracks=list(.cov100_cloud_tracks(),.cov100_cloud_tracks(.2)))
  structure(list(tracks=tracks),class="aqt_joint_refractive_scenarios")
test_that("joint 3D scenario aggregation rejects incoherent cameras, units and clocks",{
 s <- .cov100_cloud_ensemble()
 expect_error(aqt_joint_scene_cloud(list(),"S",2),"Expected 1..500")
 expect_error(aqt_joint_scene_cloud(.cov100_cloud_ensemble(list()),"S",2),
              "Expected 1..500")
 expect_error(aqt_joint_scene_cloud(s,NA_character_,2),
              "session_id must identify")
 expect_error(aqt_joint_scene_cloud(s,"",2),
              "session_id must identify")
 expect_error(aqt_joint_scene_cloud(s,"S",Inf),
              "frame_s must be finite")
 expect_error(aqt_joint_scene_cloud(s,"S",2,max_age_s=-1),
              "frame_s must be finite")
 expect_error(aqt_joint_scene_cloud(s,"S",2,probs=c(.9,.1,.5)),
              "three increasing interior")
 expect_error(aqt_joint_scene_cloud(s,"S",2,probs=c(0,.5,1)),
              "three increasing interior")
 expect_error(aqt_joint_scene_cloud(s,"S",2,probs=c(.05,.95)),
              "three increasing interior")
 expect_error(aqt_joint_scene_cloud(s,"S",2,probs=c(.05,NA,.95)),
              "three increasing interior")
 a <- as.data.frame(.cov100_cloud_tracks());a$z <- NULL
 pixel <- aqt_tracks(a)
 expect_error(aqt_joint_scene_cloud(.cov100_cloud_ensemble(list(pixel)),
              "S",2),"physical tank XYZ")
 wrong_unit <- .cov100_cloud_ensemble(list(.cov100_cloud_tracks(),
                          .cov100_cloud_tracks(unit="m")))
 expect_error(aqt_joint_scene_cloud(wrong_unit,"S",2),
              "same physical position units")
 wrong_camera <- .cov100_cloud_ensemble(list(.cov100_cloud_tracks(),
                          .cov100_cloud_tracks(cam="SECOND")))
 expect_error(aqt_joint_scene_cloud(wrong_camera,"S",2),
              "one consistent fused")
 expect_error(aqt_joint_scene_cloud(s,"NOT_S",2),
              "requested session")
 broken <- as.data.frame(.cov100_cloud_tracks());broken$assignment_changed <- NA
 invalid <- .cov100_cloud_ensemble(list(aqt_tracks(
          broken,units="cm",coordinate_system="tank")))
 expect_error(aqt_joint_scene_cloud(invalid,"S",2),
              "assignment flags must be logical")
 broken$assignment_changed <- 1L
 invalid <- .cov100_cloud_ensemble(list(aqt_tracks(
          broken,units="cm",coordinate_system="tank")))
 expect_error(aqt_joint_scene_cloud(invalid,"S",2),
              "assignment flags must be logical")
})
test_that("joint cloud retains all draw points and respects empty-camera visibility",{
 s <- .cov100_cloud_ensemble(list(.cov100_cloud_tracks(),
       .cov100_cloud_tracks(.2,assignment=TRUE)))
 cloud <- aqt_joint_scene_cloud(s,"S",2,max_age_s=.1)
 expect_s3_class(cloud,"aqt_joint_scene_cloud")
 expect_equal(nrow(cloud$points),4)
 expect_equal(cloud$n_draws,2)
 expect_equal(cloud$summary$n_visible,c(2,2))
 expect_equal(cloud$summary$visibility_fraction,c(1,1))
 expect_equal(cloud$summary$x_median,c(2.1,7.1),tolerance=1e-10)
 expect_true(all(cloud$summary$assignment_changed_fraction_among_visible==.5))
 expect_false(cloud$posterior_claim)
 expect_false(cloud$coverage_calibrated)
 none <- aqt_joint_scene_cloud(s,"S",-1)
 expect_equal(nrow(none$points),0L)
 expect_true(all(none$summary$n_visible==0))
 expect_true(all(is.na(none$summary$x_median)))
 no_recent <- aqt_joint_scene_cloud(s,"S",5,max_age_s=.1)
 expect_equal(nrow(no_recent$points),0L)
 expect_error(aqt_plot_joint_scene_cloud(none),"No observed 3D")
 expect_error(aqt_plot_joint_scene_cloud3d(none),"No observed 3D")
 expect_error(aqt_plot_joint_scene_cloud(list()),"Expected an aqt_joint_scene_cloud")
 grDevices::pdf(tempfile(fileext=".pdf"))
 on.exit(grDevices::dev.off(),add=TRUE)
 expect_invisible(aqt_plot_joint_scene_cloud(cloud,plane="xy"))
 expect_invisible(aqt_plot_joint_scene_cloud(cloud,plane="xz"))
 expect_invisible(aqt_plot_joint_scene_cloud(cloud,plane="yz"))
 fixed <- .cov100_cloud_ensemble(list(
      .cov100_cloud_tracks(shift=0),.cov100_cloud_tracks(shift=0)))
 same <- aqt_joint_scene_cloud(fixed,"S",2)
 expect_true(all(same$summary$x_lower==same$summary$x_upper))
 expect_invisible(aqt_plot_joint_scene_cloud(same))
})
