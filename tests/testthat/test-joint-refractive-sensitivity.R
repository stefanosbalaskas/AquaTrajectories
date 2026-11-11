# A deterministic synthetic stereo fixture. 3D positions lie in the
# z=1 plane, under an equal-index flatport limiting case. No claim of
# real-camera or real-fish biological accuracy is made.

.aqt_joint_test_fixture <- function(tanks=c("C1","C2","T1","T2"),
                                    n_fish=2L) {
  K <- diag(3)
  cam <- function(cx) aqt_flatport_camera(
    K,diag(3),c(cx,0,-1),c(0,0,0),c(0,0,1),
    glass_thickness=.1,n_first=1,n_glass=1,n_water=1,units="cm")
  a <- list();b <- list();cor <- list();k <- 0L
  for (sid in tanks) {
    treatment <- if (substr(sid,1,1)=="T") "treatment" else "control"
    for (fish in seq_len(n_fish)) {
      k <- k+1L
      t <- 0:6
      bonus <- if (treatment=="treatment") .1 else 0
      true_x <- fish*.1+.1*t+bonus*pmax(t-3,0)
      yy <- rep(fish*.03,length(t))
      aa <- (true_x+1)/2
      bb <- (true_x-1)/2
      aid <- paste0("A",fish)
      bid <- paste0("B",fish)
      a[[k]] <- data.frame(session_id=sid,camera_id="TOP",
        track_id=aid,time_s=t,x=aa,y=yy/2)
      b[[k]] <- data.frame(session_id=sid,camera_id="SIDE",
        track_id=bid,time_s=t,x=bb,y=yy/2)
      cor[[k]] <- data.frame(session_id=sid,id_a=aid,id_b=bid,
        time_a_s=t,time_b_s=t,fish_id=paste0("F",fish),
        tank_id=sid,treatment=treatment)
    }
  }
  list(view_a=aqt_tracks(do.call(rbind,a)),
       view_b=aqt_tracks(do.call(rbind,b)),
       correspondences=do.call(rbind,cor),
       camera_a=cam(-1),camera_b=cam(1),
       events=data.frame(session_id=tanks,event_id="feed",
         start_s=3,end_s=3),
       windows=list(baseline=c(-3,0),response=c(0,3)))
}

test_that("zero-noise optical draws reproduce known 3D paths with RNG unchanged", {
  f <- .aqt_joint_test_fixture()
  set.seed(45); prior <- .Random.seed
  a <- aqt_joint_refractive_scenarios(f$view_a,f$view_b,
    f$correspondences,f$camera_a,f$camera_b,draws=10,seed=77)
  expect_identical(.Random.seed,prior)
  expect_s3_class(a,"aqt_joint_refractive_scenarios")
  expect_equal(length(a$tracks),10)
  expect_equal(nrow(a$calibration_draws),10)
  expect_equal(nrow(a$quality),10)
  expect_true(all(a$quality$n_valid==nrow(f$correspondences)))
  expect_true(all(a$quality$max_ray_separation<1e-8))
  expect_equal(a$tracks[[1L]]$x,a$tracks[[10L]]$x)
  expect_true(all(abs(a$tracks[[1L]]$z-1)<1e-8))
  expect_false(a$assumptions$uncertainty_interval_calibrated)
  expect_false(a$assumptions$cross_view_identity_fixed==FALSE)
  ep <- aqt_joint_event_sensitivity(
    a,f$events,windows=f$windows,max_gap_s=1.1)
  expect_equal(length(unique(ep$draw)),10)
  expect_true(all(is.finite(ep$value)))
  expect_true(all(ep$epoch %in% c("baseline","response")))
  fit <- aqt_joint_tank_sensitivity(
    a,f$events,windows=f$windows,
    tank_bootstrap_draws=100,seed=49)
  expect_equal(nrow(fit$per_draw),10)
  expect_equal(fit$conditional_sd,0,tolerance=1e-9)
  expect_equal(fit$conditional_95pct_range,c(.075,.075),
               tolerance=1e-8)
  expect_true(all(fit$per_draw$n_tanks_control==2))
  expect_true(all(fit$per_draw$n_tanks_treatment==2))
  expect_false(fit$calibrated_combined_interval)
  expect_false(fit$treatment_causal)
})

test_that("coherent camera offsets are shared across a recording", {
  f <- .aqt_joint_test_fixture(tanks="C1")
  a <- aqt_joint_refractive_scenarios(f$view_a,f$view_b,
    f$correspondences,f$camera_a,f$camera_b,
    pixel_sd=0,center_sd=.01,glass_thickness_sd=.003,
    n_glass_sd=0,n_water_sd=0,draws=20,seed=12)
  expect_gt(stats::sd(a$calibration_draws$center_a_x),0)
  expect_gt(stats::sd(a$calibration_draws$thickness_a),0)
  expect_true(all(a$quality$n_valid==nrow(f$correspondences)))
  expect_true(all(a$calibration_draws$thickness_a>0))
  expect_gt(stats::sd(vapply(a$tracks,function(d)d$x[1],
                            numeric(1L))),0)
})

test_that("whole-future identity switches affect entire reconstructed tracks", {
  f <- .aqt_joint_test_fixture(tanks="C1")
  event <- data.frame(session_id="C1",camera_id="REFRACTIVE3D",
      track_a="F1",track_b="F2",at_s=3,probability_swap=1)
  out <- aqt_joint_refractive_scenarios(
    f$view_a,f$view_b,f$correspondences,f$camera_a,f$camera_b,
    identity_events=event,draws=10,seed=19)
  expect_true(all(out$quality$n_selected_identity_swaps==1))
  track <- out$tracks[[1]]
  expect_equal(sum(track$assignment_changed),8)
  expect_true(all(track$track_id[track$original_track_id=="F1" &
                                 track$time_s>=3]=="F2"))
  expect_true(all(track$track_id[track$original_track_id=="F2" &
                                 track$time_s>=3]=="F1"))
  expect_true(all(track$track_id[track$time_s<3] ==
                  track$original_track_id[track$time_s<3]))
})

test_that("invalid physical uncertainty and corrupt correspondence scope fail", {
  f <- .aqt_joint_test_fixture(tanks="C1")
  args <- list(view_a=f$view_a,view_b=f$view_b,
     correspondences=f$correspondences,camera_a=f$camera_a,
     camera_b=f$camera_b,draws=10,seed=1)
  expect_error(do.call(aqt_joint_refractive_scenarios,
                      c(args,list(pixel_sd=-1))),"pixel_sd")
  expect_error(do.call(aqt_joint_refractive_scenarios,
                      c(args,list(n_glass_sd=-.1))),"Refractive index")
  expect_error(do.call(aqt_joint_refractive_scenarios,
                      c(args,list(draws=2))),"draws")
  bad <- f$correspondences
  bad$fish_id[1] <- "unspecified"
  expect_error(aqt_refractive_reconstruct_tracks(
    f$view_a,f$view_b,bad,f$camera_a,f$camera_b),
    "Duplicate time within scoped track|multiple fused fish")
})
