.aqt_sync_holdout_fixture <- function() {
  ids <- paste0("M",1:9)
  physical <- seq(0,80,by=10)
  records <- list();k<-0L
  for (s in c("S1","S2")) {
    b <- if (s=="S1") .1 else -.2
    a <- if (s=="S1") 1.0002 else .9998
    for (cam in c("TOP","SIDE")) {
      k <- k+1L
      records[[k]] <- data.frame(
        session_id=s,camera_id=cam,marker_id=ids,
        time_s=if(cam=="TOP")physical else (physical-b)/a)
    }
  }
  do.call(rbind,records)
}

test_that("independent sync holdouts recover offsets and drift without leakage", {
  x <- .aqt_sync_holdout_fixture()
  fit <- aqt_sync_holdout_fit(x,"TOP",paste0("M",1:6),
          paste0("M",7:9),max_holdout_error_s=.0001)
  expect_s3_class(fit,"aqt_clock_holdout")
  expect_equal(nrow(fit$fits),4)
  expect_equal(nrow(fit$holdout),12)
  expect_true(all(fit$fits$within_tolerance))
  expect_true(all(fit$fits$holdout_max_abs_s<1e-8))
  expect_true(all(fit$fits$holdout_extrapolates))
  s1 <- fit$fits[fit$fits$session_id=="S1" &
                 fit$fits$camera_id=="SIDE",]
  s2 <- fit$fits[fit$fits$session_id=="S2" &
                 fit$fits$camera_id=="SIDE",]
  expect_equal(s1$intercept_s,.1,tolerance=1e-9)
  expect_equal(s1$slope,1.0002,tolerance=1e-10)
  expect_equal(s2$intercept_s,-.2,tolerance=1e-9)
  expect_equal(s2$slope,.9998,tolerance=1e-10)
  expect_equal(s1$drift_ppm,200,tolerance=1e-7)
  expect_false(fit$pulses_independently_verified)
  expect_false(fit$camera_timing_certified)
})

test_that("synced tracks retain source timestamps and original session scope", {
  m <- .aqt_sync_holdout_fixture()
  fit <- aqt_sync_holdout_fit(m,"TOP",paste0("M",1:6),
                             paste0("M",7:9))
  d <- do.call(rbind,lapply(c("S1","S2"),function(s) {
    k <- if (s=="S1") .1 else -.2
    a <- if (s=="S1") 1.0002 else .9998
    data.frame(session_id=s,camera_id=rep(c("TOP","SIDE"),each=3),
      track_id=c(rep("A",3),rep("B",3)),
      time_s=c(c(20,30,40),(c(20,30,40)-k)/a),
      x=rep(0:2,2),y=0)
  }))
  raw <- aqt_tracks(d)
  result <- aqt_sync_holdout_apply(raw,fit,max_extrapolation_s=1)
  expect_s3_class(result,"aqt_tracks")
  expect_equal(result$time_s,rep(rep(c(20,30,40),2),2),
               tolerance=1e-8)
  expect_true(any(abs(result$time_raw_s-result$time_s)>.05))
  expect_true(all(result$clock_within_tolerance))
  expect_true(all(result$clock_extrapolation_s==0))
  expect_false(attr(result,"aqt_clock_pulse_verification"))
  expect_error(aqt_sync_holdout_apply(result,fit),
               "already contain time_raw_s")
})

test_that("independent holdout errors block false confidence in camera clocks", {
  m <- .aqt_sync_holdout_fixture()
  idx <- which(m$session_id=="S1" & m$camera_id=="SIDE" &
               m$marker_id=="M9")
  m$time_s[idx] <- m$time_s[idx]+.03
  fit <- aqt_sync_holdout_fit(m,"TOP",paste0("M",1:6),
                             paste0("M",7:9),
                             max_holdout_error_s=.005)
  bad <- fit$fits[fit$fits$session_id=="S1" &
                  fit$fits$camera_id=="SIDE",]
  expect_false(bad$within_tolerance)
  expect_gt(bad$holdout_max_abs_s,.02)
  camera <- aqt_tracks(data.frame(session_id="S1",
    camera_id="SIDE",track_id="F",time_s=(20-.1)/1.0002,x=0,y=0))
  expect_error(aqt_sync_holdout_apply(camera,fit),
               "fails heldout synchronization")
  tolerated <- aqt_sync_holdout_apply(camera,fit,
                require_tolerance=FALSE,max_extrapolation_s=0)
  expect_false(tolerated$clock_within_tolerance)
  expect_equal(tolerated$time_s,20,tolerance=1e-8)
})

test_that("sync holdout rejects camera marker omission and training overlap", {
  m <- .aqt_sync_holdout_fixture()
  expect_error(aqt_sync_holdout_fit(m,"TOP",
    c("M1","M2","M3","M4"),c("M4","M5")),
    "disjoint")
  expect_error(aqt_sync_holdout_fit(m,"TOP",
    c("M1","M2","M3"),c("M5","M6")),
    ">=4 training")
  absent <- m[!(m$session_id=="S2" & m$camera_id=="SIDE" &
                  m$marker_id=="M9"),]
  expect_error(aqt_sync_holdout_fit(absent,"TOP",
    paste0("M",1:6),paste0("M",7:9)),
    "missing a required sync pulse")
  duplicate <- rbind(m,m[1,,drop=FALSE])
  expect_error(aqt_sync_holdout_fit(duplicate,"TOP",
    paste0("M",1:6),paste0("M",7:9)),
    "Duplicate pulse")
  fit <- aqt_sync_holdout_fit(m,"TOP",
    paste0("M",1:6),paste0("M",7:9))
  out_of_support <- aqt_tracks(data.frame(session_id="S1",
    camera_id="SIDE",track_id="F",time_s=-5,x=0,y=0))
  expect_error(aqt_sync_holdout_apply(out_of_support,fit),
               "pulse support")
})

test_that("training and independently heldout pulses may be interleaved", {
  m <- .aqt_sync_holdout_fixture()
  # Deliberately interleave both sets and supply non-chronological IDs.
  # Holdouts between training pulses give interpolation rather than
  # artificially forcing every holdout to extrapolate beyond training.
  fit <- aqt_sync_holdout_fit(
    m,"TOP",c("M7","M1","M5","M3"),
    c("M6","M2","M4"),max_holdout_error_s=.0001)
  expect_true(all(fit$fits$within_tolerance))
  expect_true(all(fit$fits$holdout_max_abs_s<1e-8))
  expect_false(any(fit$fits$holdout_extrapolates))
  expect_equal(fit$fits$n_training,rep(4,4))
  expect_equal(fit$fits$n_holdout,rep(3,4))

  # Physical matching is still necessary: non-monotone camera timestamps
  # against physically ordered reference events must be rejected.
  corrupt <- m
  i <- which(corrupt$session_id=="S1" &
             corrupt$camera_id=="SIDE" &
             corrupt$marker_id %in% c("M3","M5"))
  corrupt$time_s[i] <- rev(corrupt$time_s[i])
  expect_error(
    aqt_sync_holdout_fit(corrupt,"TOP",c("M7","M1","M5","M3"),
                         c("M6","M2","M4")),
    "physical order")
})
