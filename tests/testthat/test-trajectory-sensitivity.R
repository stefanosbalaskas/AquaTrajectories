test_that("zero-error draws preserve known 2D speed and global RNG", {
  x <- aqt_tracks(data.frame(
    session_id="S1",camera_id="TOP",track_id="F1",
    time_s=0:4,x=0:4,y=0),units="cm",coordinate_system="tank")
  set.seed(123); previous <- .Random.seed
  e <- aqt_trajectory_ensemble(x,sigma=0,systematic_sd=0,
                               rho=.4,draws=30,seed=72)
  expect_identical(.Random.seed,previous)
  expect_s3_class(e,"aqt_trajectory_ensemble")
  expect_equal(dim(e$positions),c(5,2,30))
  expect_equal(aqt_ensemble_tracks(e,1)$x,0:4)
  result <- aqt_ensemble_path_summary(e,max_gap_s=2)
  expect_equal(nrow(result),30)
  expect_true(all(result$path_length==4))
  expect_true(all(result$mean_speed==1))
  summary <- aqt_ensemble_summarize(result,value_col="mean_speed")
  expect_equal(summary$conditional_mean,1)
  expect_equal(summary$conditional_sd,0)
  expect_equal(c(summary$lower,summary$upper),c(1,1))
  expect_equal(summary$n_draws,30)
  expect_match(attr(summary,"aqt_interval_type"),"sensitivity")
})

test_that("correlated scenarios stay scoped and do not invent missing fish", {
  x <- aqt_tracks(data.frame(session_id="S1",camera_id="TOP",
     track_id=rep(c("A","B"),each=4),
     time_s=rep(0:3,2),x=c(0,1,2,3,10,11,12,13),
     y=c(0,0,0,0,5,5,5,5),
     observed=c(TRUE,TRUE,FALSE,TRUE,TRUE,TRUE,TRUE,TRUE)))
  a <- aqt_trajectory_ensemble(x,sigma=.1,rho=.7,
    systematic_sd=.2,draws=40,seed=6,max_gap_s=1)
  b <- aqt_trajectory_ensemble(x,sigma=.1,rho=.7,
    systematic_sd=.2,draws=40,seed=6,max_gap_s=1)
  expect_equal(a$positions,b$positions)
  y <- aqt_ensemble_tracks(a,1)
  expect_true(is.na(y$x[y$track_id=="A" & y$time_s==2]))
  expect_false(y$observed[y$track_id=="A" & y$time_s==2])
  s <- aqt_ensemble_path_summary(a,max_gap_s=1)
  expect_equal(nrow(s),80)
  expect_true(all(s$valid_steps[s$track_id=="A"]==1))
  expect_true(all(s$valid_steps[s$track_id=="B"]==3))
})

test_that("3D conditional ensembles yield coordinate-aware draws", {
  x <- aqt_tracks(data.frame(session_id="S1",camera_id="FUSED3D",
    track_id="A",time_s=0:2,x=0:2,y=c(0,1,2),z=c(3,3,3)),
    units="cm",coordinate_system="tank")
  e <- aqt_trajectory_ensemble(x,sigma=c(.1,.2,.3),
                               systematic_sd=c(0,0,0),
                               draws=20,seed=22)
  expect_equal(dim(e$positions),c(3,3,20))
  expect_true(aqt_tracks_validate(aqt_ensemble_tracks(e,3)))
  expect_equal(aqt_ensemble_tracks(e,3)$z[1] != x$z[1],TRUE)
  expect_error(aqt_trajectory_ensemble(x,sigma=c(.1,.2),
              draws=20),"sigma")
  expect_error(aqt_trajectory_ensemble(x,rho=1,draws=20),"rho")
  expect_error(aqt_trajectory_ensemble(x,draws=5),"draws")
})

test_that("uncertainty scenarios propagate into event window metrics", {
  x <- aqt_tracks(data.frame(session_id="S1",camera_id="TOP",
    track_id="F1",time_s=0:8,x=0:8,y=0),
    units="cm",coordinate_system="tank")
  e <- aqt_trajectory_ensemble(x,sigma=0,draws=25,seed=5)
  events <- data.frame(session_id="S1",event_id="feed",
                       start_s=4,end_s=5)
  out <- aqt_ensemble_event_summary(e,events,outcome="speed",
     windows=list(baseline=c(-3,0),response=c(0,3)),
     estimator="time_weighted",max_gap_s=1.1)
  expect_equal(nrow(out),50)
  expect_true(all(out$value==1))
  expect_equal(sort(unique(out$epoch)),c("baseline","response"))
  stats <- aqt_ensemble_summarize(out,value_col="value",
    group_cols=c("session_id","event_id","epoch","camera_id","track_id"))
  expect_equal(nrow(stats),2)
  expect_true(all(stats$conditional_sd==0))
  expect_true(all(stats$n_draws==25))
  out2 <- out
  out2 <- rbind(out2,out[1,,drop=FALSE])
  expect_error(aqt_ensemble_summarize(out2,value_col="value",
    group_cols=c("session_id","event_id","epoch","camera_id","track_id")),
    "More than one")
})

test_that("2D sensitivity graphics work in headless PDF", {
  x <- aqt_tracks(data.frame(session_id="S1",camera_id="TOP",
    track_id="F",time_s=0:4,x=0:4,y=c(0,1,0,1,0)))
  e <- aqt_trajectory_ensemble(x,sigma=.1,draws=20,seed=14)
  path <- tempfile(fileext=".pdf")
  grDevices::pdf(path)
  tryCatch({
    idx <- aqt_plot_ensemble2d(e,"S1","TOP","F",n_draws=5)
    expect_equal(length(idx),5)
  },finally=grDevices::dev.off())
  expect_true(file.exists(path))
  unlink(path)
  expect_error(aqt_plot_ensemble2d(e,"S1","TOP","missing"),"No fish track")
})
