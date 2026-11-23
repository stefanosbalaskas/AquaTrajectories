
# New 100%-coverage campaign: explicit falsification of input schemas, affine
# sync assumptions and conditional-trajectory scenario interpretation.
# Synthetic records only; no empirical fish data or detector claims.

.cov100_tracks <- function() {
  data.frame(session_id="S1",camera_id="C1",track_id="0001",
    time_s=c(0,.1,.2,.3),x=c(1,2,3,4),y=c(4,3,2,1),
    stringsAsFactors=FALSE)
}

test_that("canonical trajectories reject invalid units, axes and incomplete observations", {
  d <- .cov100_tracks()
  expect_error(aqt_tracks(NULL),"data.frame")
  expect_error(aqt_tracks(data.frame(x=1)),"Missing columns")
  expect_error(aqt_tracks(d,units="meters"),"Unsupported units")
  expect_error(aqt_tracks(d,coordinate_system="world"),"Unsupported coordinate system")
  bad <- d;bad$track_id[1] <- ""
  expect_error(aqt_tracks(bad),"nonempty identifiers")
  bad <- d;bad$session_id[1] <- NA_character_
  expect_error(aqt_tracks(bad),"nonempty identifiers")
  bad <- d;bad$time_s[2] <- Inf
  expect_error(aqt_tracks(bad),"time_s must be finite")
  bad <- d;bad$x[2] <- Inf
  expect_error(aqt_tracks(bad),"Coordinates cannot be infinite")
  bad <- d;bad$x[2] <- NA_real_
  expect_error(aqt_tracks(bad),"both be present or both missing")
  bad <- d;bad$z <- letters[1:4]
  expect_error(aqt_tracks(bad),"z must be numeric")
  bad <- d;bad$z <- c(0,1,2,3)
  expect_error(aqt_tracks(bad),"3D trajectories require tank")
  bad <- d;bad$observed <- c(TRUE,TRUE,NA,TRUE)
  expect_error(aqt_tracks(bad),"observed must be")
  bad <- rbind(d,d[1,,drop=FALSE])
  expect_error(aqt_tracks(bad),"Duplicate time")
  bad <- d;bad$x[2] <- NA_real_;bad$y[2] <- NA_real_
  tr <- aqt_tracks(bad)
  expect_false(tr$observed[2])
  expect_true(all(is.finite(tr$time_s)))
  expect_identical(attr(tr,"aqt_dimension"),2L)
  tank <- d;tank$z <- as.integer(c(1,2,3,4))
  tr3 <- aqt_tracks(tank,units="cm",coordinate_system="tank")
  expect_identical(attr(tr3,"aqt_dimension"),3L)
  expect_true(is.double(tr3$z))
  expect_output(print(tr3),"<aqt_tracks>")
  expect_error(aqt_tracks_validate(data.frame()),"Expected aqt_tracks")
})

test_that("CSV, YOLO and idtracker.ai adapters preserve camera-local IDs and detect missing clocks", {
  d <- .cov100_tracks()
  d$track_id <- "0009"
  p <- tempfile(fileext=".csv")
  on.exit(unlink(p),add=TRUE)
  utils::write.csv(d,p,row.names=FALSE)
  tr <- aqt_import_csv(p)
  expect_identical(unique(tr$track_id),"0009")
  y <- data.frame(fish_id=c("0002","0002"),frame=0:1,
                  x_px=c(1,2),y_px=c(3,4))
  utils::write.csv(y,p,row.names=FALSE)
  expect_error(aqt_import_yolo(p,"S","C"),"positive fps")
  yolo <- aqt_import_yolo(p,"S","C",fps=20)
  expect_identical(unique(yolo$track_id),"0002")
  expect_equal(yolo$time_s,c(0,.05))
  y$frame <- NULL
  utils::write.csv(y,p,row.names=FALSE)
  expect_error(aqt_import_yolo(p,"S","C",fps=30),"positive fps")
  y$time_s <- c(0,.04)
  utils::write.csv(y,p,row.names=FALSE)
  expect_equal(aqt_import_yolo(p,"S","C")$time_s,c(0,.04))
  y$fish_id <- NULL
  utils::write.csv(y,p,row.names=FALSE)
  expect_error(aqt_import_yolo(p,"S","C"),"track_id/fish_id")
  utils::write.csv(data.frame(track_id="0003",time_s=0,x=1),p,row.names=FALSE)
  expect_error(aqt_import_idtracker(p,"S","C"),"long-format")
  utils::write.csv(data.frame(track_id=c("0003","0003"),
      time_s=c(0,1),x=c(1,2),y=c(2,3)),p,row.names=FALSE)
  id <- aqt_import_idtracker(p,"S","C")
  expect_identical(unique(id$track_id),"0003")
})

test_that("event validation and alignment preserve empty-event schema and overlapping periods", {
  tr <- aqt_tracks(.cov100_tracks())
  expect_error(aqt_event_table(list()),"Missing event columns")
  expect_error(aqt_event_table(data.frame(session_id="S1")),"Missing event columns")
  ev <- data.frame(session_id="S1",event_id="E",start_s=.1,end_s=.2)
  bad <- ev;bad$event_id <- ""
  expect_error(aqt_event_table(bad),"Missing event identifier")
  bad <- ev;bad$end_s <- 0
  expect_error(aqt_event_table(bad),"Invalid event start/end")
  bad <- ev;bad$start_s <- "not time"
  expect_error(aqt_event_table(bad),"Invalid event start/end")
  bad <- rbind(ev,ev)
  expect_error(aqt_event_table(bad),"Duplicate event")
  expect_error(aqt_align_events(NULL,ev),"Expected session_id")
  expect_error(aqt_align_events(tr,ev,window_s=c(1,-1)),"Invalid relative time")
  expect_error(aqt_align_events(tr,ev,window_s=c(1,NA)),"Invalid relative time")
  empty <- ev[FALSE,,drop=FALSE]
  out <- aqt_align_events(tr,empty)
  expect_identical(nrow(out),0L)
  expect_true(all(c("event_start_s","event_end_s","event_id","phase") %in% names(out)))
  ev2 <- rbind(ev,transform(ev,event_id="E2",start_s=.2,end_s=.3))
  aligned <- aqt_align_events(tr,ev2,window_s=c(-.15,.2))
  expect_true(all(unique(aligned$phase) %in% c("before","during","after")))
  expect_true(all(c("E","E2") %in% aligned$event_id))
  absent <- transform(ev,session_id="not recorded")
  expect_equal(nrow(aqt_align_events(tr,absent)),0)
})

test_that("affine synchronization handles single marker, drift and bad reference clocks", {
  markers <- data.frame(camera_id=c("A","A","B","B"),marker_id=c("P","Q","P","Q"),
                        time_s=c(0,1,2,3))
  expect_error(aqt_sync_fit(NULL,"A"),"Missing marker columns")
  bad <- markers;bad$time_s[1] <- Inf
  expect_error(aqt_sync_fit(bad,"A"),"Invalid or duplicate")
  bad <- markers;bad$marker_id[2] <- "P"
  expect_error(aqt_sync_fit(bad,"A"),"Invalid or duplicate")
  expect_error(aqt_sync_fit(markers,"missing"),"Missing reference camera")
  bad <- rbind(markers, data.frame(camera_id="C",marker_id="NONE",time_s=0))
  expect_error(aqt_sync_fit(bad,"A"),"No matching markers")
  bad <- markers;bad$time_s[3:4] <- 2
  expect_error(aqt_sync_fit(bad,"A"),"Nonvarying camera marker")
  bad <- markers;bad$time_s[3:4] <- c(3,2)
  expect_error(aqt_sync_fit(bad,"A"),"Invalid clock slope")
  one <- markers[markers$marker_id=="P",]
  fitted <- aqt_sync_fit(one,"A")
  expect_equal(fitted$intercept_s[fitted$camera_id=="B"],-2)
  expect_false(fitted$drift_identifiable[fitted$camera_id=="B"])
  fit2 <- aqt_sync_fit(markers,"A")
  expect_equal(fit2$slope[fit2$camera_id=="B"],1,tolerance=1e-12)
  tr <- aqt_tracks(transform(.cov100_tracks(),camera_id="B"))
  expect_error(aqt_sync_apply(tr,data.frame(camera_id="B")),"Invalid synchronization fit")
  expect_error(aqt_sync_apply(tr,subset(fit2,camera_id=="A")),"Missing clock transform")
  r <- aqt_sync_apply(tr,fit2)
  expect_equal(r$time_s,tr$time_s-2,tolerance=1e-12)
  corrupted <- fit2;corrupted$slope[corrupted$camera_id=="B"] <- Inf
  expect_error(aqt_sync_apply(tr,corrupted),"Nonfinite synchronized time")
})

test_that("conditional ensembles reject invalid scenarios and summarize missing values honestly", {
  tr <- aqt_tracks(.cov100_tracks(),units="cm",coordinate_system="tank")
  expect_error(aqt_trajectory_ensemble(tr,rho=1,draws=20),"rho")
  expect_error(aqt_trajectory_ensemble(tr,draws=2),"draws")
  expect_error(aqt_trajectory_ensemble(tr,draws=20,seed=-1),"seed")
  expect_error(aqt_trajectory_ensemble(tr,draws=20,seed=2^32),"seed")
  expect_error(aqt_trajectory_ensemble(tr,draws=20,max_gap_s=0),"max_gap_s")
  e <- aqt_trajectory_ensemble(tr,draws=20,seed=101,
             sigma=.05,rho=.2,systematic_sd=.02,max_gap_s=.15)
  expect_s3_class(e,"aqt_trajectory_ensemble")
  expect_error(aqt_ensemble_tracks(list()),"Expected aqt_trajectory_ensemble")
  expect_error(aqt_ensemble_tracks(e,draw=0),"Invalid scenario draw index")
  expect_error(aqt_ensemble_tracks(e,draw=21),"Invalid scenario draw index")
  bad <- e;bad$positions <- bad$positions[-1,,,drop=FALSE]
  expect_error(aqt_ensemble_tracks(bad),"Invalid scenario dimensions")
  t <- aqt_ensemble_tracks(e,draw=3)
  expect_s3_class(t,"aqt_tracks")
  expect_identical(attr(t,"aqt_scenario"),3L)
  expect_error(aqt_ensemble_path_summary(list()),"Expected aqt_trajectory_ensemble")
  p <- aqt_ensemble_path_summary(e,max_gap_s=.15)
  expect_true(is.data.frame(p))
  expect_true(nrow(p)>0)
  expect_error(aqt_ensemble_event_summary(list(),data.frame()),"Expected aqt_trajectory_ensemble")
  ev <- data.frame(session_id="S1",event_id="E",start_s=.1,end_s=.2)
  out <- aqt_ensemble_event_summary(e,ev,
        windows=list(past=c(-2,-1)),min_points=2L)
  expect_true(is.data.frame(out))
  expect_equal(nrow(out),0L)
  vals <- data.frame(session_id="S1",camera_id="C1",track_id="0001",
                     draw=1:3, measure=c(1,NA,5))
  expect_error(aqt_ensemble_summarize(list(),"measure"),"Expected long scenario results")
  expect_error(aqt_ensemble_summarize(transform(vals,measure=letters[1:3]),"measure"),
               "Scenario measure must be numeric")
  expect_error(aqt_ensemble_summarize(vals,"measure",level=1),"level must")
  expect_error(aqt_ensemble_summarize(vals,"measure",group_cols=c("draw")),
               "Invalid scenario grouping")
  dup <- rbind(vals,vals[1,,drop=FALSE])
  expect_error(aqt_ensemble_summarize(dup,"measure"),"More than one scenario")
  result <- aqt_ensemble_summarize(vals,"measure")
  expect_equal(result$n_draws,2)
  expect_equal(result$conditional_mean,3)
  all_na <- vals
  all_na$measure <- NA_real_
  report <- aqt_ensemble_summarize(all_na,"measure")
  expect_equal(report$n_draws,0)
  expect_true(is.na(report$conditional_sd))
  expect_true(is.na(report$lower))
})
