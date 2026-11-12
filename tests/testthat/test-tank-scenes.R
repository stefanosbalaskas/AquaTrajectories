.aqt_scene_fixture <- function() {
  x <- do.call(rbind,lapply(c("A","B"),function(id) {
    data.frame(session_id="S1",camera_id="FUSED3D",
      track_id=id,time_s=0:4,
      x=0:4,y=if (id=="A") 0 else 1,
      z=(0:4)*.1+1,observed=rep(TRUE,5))
  }))
  aqt_tracks(x,units="cm",coordinate_system="tank")
}

test_that("3D snapshots use current real observed positions and event telemetry", {
  tracks <- .aqt_scene_fixture()
  events <- data.frame(session_id="S1",event_id="feeding",
     start_s=2,end_s=2)
  scene <- aqt_tank_scene_snapshot(tracks,frame_s=2,
       tail_s=2,max_age_s=0,max_gap_s=1.1,events=events)
  expect_s3_class(scene,"aqt_tank_scene")
  expect_equal(scene$n_visible,2)
  expect_equal(scene$heads$time_s,c(2,2))
  expect_equal(unique(scene$heads$z),1.2)
  expect_true(all(scene$heads$age_s==0))
  expect_equal(scene$active_events,"feeding")
  expect_equal(scene$recent_events,"feeding")
  expect_false(scene$calibration_certified)
  expect_true(all(scene$tails$segment_id==1))
  expect_equal(nrow(scene$tails),6)
})

test_that("explicit missing fish at latest frame cannot be shown as stale", {
  tracks <- .aqt_scene_fixture()
  tracks$observed[tracks$track_id=="A" & tracks$time_s==2] <- FALSE
  tracks$x[tracks$track_id=="A" & tracks$time_s==2] <- NA_real_
  tracks$y[tracks$track_id=="A" & tracks$time_s==2] <- NA_real_
  tracks$z[tracks$track_id=="A" & tracks$time_s==2] <- NA_real_
  scene <- aqt_tank_scene_snapshot(tracks,frame_s=2,
      tail_s=2,max_age_s=2,max_gap_s=1.1)
  expect_equal(scene$n_visible,1)
  expect_equal(scene$heads$track_id,"B")
  expect_true(all(scene$tails$track_id=="B"))
})

test_that("tails split at missed frames and tracking gaps", {
  tracks <- .aqt_scene_fixture()
  tracks$observed[tracks$track_id=="B" & tracks$time_s==2] <- FALSE
  scene <- aqt_tank_scene_snapshot(tracks,frame_s=4,
     tail_s=4,max_age_s=0,max_gap_s=1.1)
  b <- scene$tails[scene$tails$track_id=="B",]
  expect_equal(b$time_s,c(0,1,3,4))
  expect_equal(b$segment_id,c(1,1,2,2))
  scene2 <- aqt_tank_scene_snapshot(tracks,frame_s=4,
     tail_s=4,max_age_s=0,max_gap_s=.5)
  expect_true(all(table(scene2$tails$segment_id[
    scene2$tails$track_id=="B"])==1))
})

test_that("scene storyboard is chronological and 2D views use measured 3D", {
  tracks <- .aqt_scene_fixture()
  frames <- aqt_tank_scene_storyboard(tracks,c(1,2,3),
     tail_s=1,max_age_s=.01,max_gap_s=1.1)
  expect_s3_class(frames,"aqt_tank_storyboard")
  expect_equal(length(frames),3)
  expect_equal(vapply(frames,function(x)x$frame_s,numeric(1L)),
               c(1,2,3))
  file <- tempfile(fileext=".pdf")
  grDevices::pdf(file)
  tryCatch({
    expect_s3_class(aqt_plot_tank_projection(frames[[1]],"xy"),
                    "aqt_tank_scene")
    expect_s3_class(aqt_plot_tank_projection(frames[[2]],"xz"),
                    "aqt_tank_scene")
    expect_s3_class(aqt_plot_tank_projection(frames[[3]],"yz"),
                    "aqt_tank_scene")
  },finally=grDevices::dev.off())
  expect_true(file.exists(file))
  unlink(file)
})

test_that("2D, multi-camera, and unobserved-only scenes are refused", {
  tracks <- .aqt_scene_fixture()
  tracks2 <- aqt_tracks(as.data.frame(tracks)[,c("session_id",
    "camera_id","track_id","time_s","x","y","observed")])
  expect_error(aqt_tank_scene_snapshot(tracks2,2),
               "measured physical XYZ")
  many <- tracks
  many$camera_id[many$track_id=="B"] <- "SIDE"
  expect_error(aqt_tank_scene_snapshot(many,2),
               "one session and one fused")
  empty <- aqt_tank_scene_snapshot(tracks,frame_s=10,
      tail_s=1,max_age_s=.01)
  expect_equal(empty$n_visible,0)
  expect_error(aqt_plot_tank_projection(empty),"No verified")
  expect_error(aqt_tank_scene_storyboard(tracks,c(2,1)),
               "strictly increasing")
})
