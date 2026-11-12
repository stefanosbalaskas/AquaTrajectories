.aqt_cloud_fixture <- function(draws=10L) {
  all <- lapply(seq_len(draws),function(i) {
    fish <- rep(c("F1","F2"),each=4)
    time <- rep(0:3,2)
    idx2 <- fish=="F2" & time==3
    missing <- i>8L & idx2
    d <- data.frame(session_id="S",camera_id="REFRACTIVE3D",
      track_id=fish,time_s=time,
      x=ifelse(fish=="F1",time+.01*i,5+time+.01*i),
      y=ifelse(fish=="F1",0,1),z=rep(1.5,length(time)),
      observed=!missing,
      assignment_changed=fish=="F1" & time>=3 & i<=5L)
    d$x[missing] <- NA_real_
    d$y[missing] <- NA_real_
    d$z[missing] <- NA_real_
    aqt_tracks(d,units="cm",coordinate_system="tank")
  })
  structure(list(tracks=all,assumptions=list(
    optical_parameters_calibrated=FALSE,
    uncertainty_interval_calibrated=FALSE)),
    class="aqt_joint_refractive_scenarios")
}

test_that("fish optical/ID cloud retains every physical XYZ draw and missingness", {
  src <- .aqt_cloud_fixture()
  out <- aqt_joint_scene_cloud(src,session_id="S",
     frame_s=3,max_age_s=0)
  expect_s3_class(out,"aqt_joint_scene_cloud")
  expect_equal(out$n_draws,10)
  expect_equal(nrow(out$points),18)
  expect_equal(out$units,"cm")
  a <- out$summary[out$summary$track_id=="F1",]
  b <- out$summary[out$summary$track_id=="F2",]
  expect_equal(a$n_visible,10)
  expect_equal(a$visibility_fraction,1)
  expect_equal(a$assignment_changed_fraction_among_visible,.5)
  expect_equal(b$n_visible,8)
  expect_equal(b$visibility_fraction,.8)
  expect_equal(b$assignment_changed_fraction_among_visible,0)
  expect_equal(a$x_median,3+.055,tolerance=1e-12)
  expect_lt(a$x_lower,a$x_upper)
  expect_true(all(out$points$time_s==3))
  expect_false(out$posterior_claim)
  expect_false(out$coverage_calibrated)
  expect_true(out$multimodality_preserved)
})

test_that("latest unobserved position does not fall back to an older fish", {
  src <- .aqt_cloud_fixture()
  out <- aqt_joint_scene_cloud(src,"S",3,max_age_s=5)
  expect_equal(sum(out$points$track_id=="F2"),8)
  expect_true(all(out$points$time_s==3))
  expect_equal(nrow(out$summary),2)
})

test_that("3D clouds support XY, XZ, YZ headless publication graphics", {
  out <- aqt_joint_scene_cloud(.aqt_cloud_fixture(),"S",3,0)
  filepath <- tempfile(fileext=".pdf")
  grDevices::pdf(filepath)
  tryCatch({
    expect_s3_class(aqt_plot_joint_scene_cloud(out,"xy"),
                    "aqt_joint_scene_cloud")
    expect_s3_class(aqt_plot_joint_scene_cloud(out,"xz"),
                    "aqt_joint_scene_cloud")
    expect_s3_class(aqt_plot_joint_scene_cloud(out,"yz"),
                    "aqt_joint_scene_cloud")
  },finally=grDevices::dev.off())
  expect_true(file.exists(filepath))
  unlink(filepath)
})

test_that("joint cloud errors on invalid units, missing session or fake 2D", {
  src <- .aqt_cloud_fixture()
  src$tracks[[10]] <- aqt_tracks(
    as.data.frame(src$tracks[[10]]),
    units="m",coordinate_system="tank")
  expect_error(aqt_joint_scene_cloud(src,"S",3),
               "same physical position units")
  src <- .aqt_cloud_fixture()
  expect_error(aqt_joint_scene_cloud(src,"nonexistent",3),
               "requested session")
  xy <- as.data.frame(src$tracks[[2L]])
  xy$z <- NULL
  src$tracks[[2L]] <- aqt_tracks(xy,units="px",
       coordinate_system="image")
  expect_error(aqt_joint_scene_cloud(src,"S",3),
               "physical tank XYZ")
  expect_error(aqt_joint_scene_cloud(list(),"S",3),
               "Expected")
  expect_error(aqt_joint_scene_cloud(.aqt_cloud_fixture(),"S",3,
               probs=c(.5,.2,.95)),
               "increasing")
})

test_that("cloud records invisible fish without inventing a position", {
  src <- .aqt_cloud_fixture()
  for (i in seq_along(src$tracks)) {
    d <- as.data.frame(src$tracks[[i]])
    row <- which(d$track_id=="F2" & d$time_s==3)
    d$observed[row] <- FALSE
    d[row,c("x","y","z")] <- NA_real_
    src$tracks[[i]] <- aqt_tracks(d,units="cm",
                                  coordinate_system="tank")
  }
  out <- aqt_joint_scene_cloud(src,"S",3,max_age_s=10)
  b <- out$summary[out$summary$track_id=="F2",]
  expect_equal(b$n_visible,0)
  expect_equal(b$visibility_fraction,0)
  expect_true(is.na(b$x_median))
  expect_equal(nrow(out$points),10)
})
