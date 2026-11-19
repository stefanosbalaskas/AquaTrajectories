# Synthetic numerical oracles for the unified scientific analysis layer.
# All results are engineering fixtures, not observed fish behaviour.

make_research_fixture <- function(nfish=3L,frames=0:5,
                                  excluded=NULL,session="S",camera="TOP",
                                  tank=NULL,treatment=NULL) {
  ff <- data.frame(session_id=session,camera_id=camera,
    frame_id=0:5,time_s=(0:5)/10,
    width_px=100,height_px=80,stringsAsFactors=FALSE)
  rows <- lapply(seq_len(nfish),function(id) {
    f <- frames
    data.frame(session_id=session,camera_id=camera,
      track_id=sprintf("%04d",id),
      frame_id=f,time_s=f/10,
      x=if(id==1L) f else if(id==2L) f else rep(3,length(f)),
      y=if(id==1L) rep(0,length(f)) else if(id==2L)
        rep(3,length(f)) else rep(0,length(f)),
      observed=TRUE,detection_confidence=.95)
  })
  raw <- do.call(rbind,rows); rownames(raw) <- NULL
  if (!is.null(excluded)) {
    i <- which(raw$track_id=="0001" & raw$frame_id==excluded)
    raw$observed[i] <- FALSE
    raw$x[i] <- NA_real_; raw$y[i] <- NA_real_
  }
  q <- aqt_trajectory_qc(raw,ff,max_gap_s=.11)
  list(review=aqt_qc_review(q),events=data.frame(
    session_id=session,event_id="feed",start_s=.3,end_s=.3),
    design=if(is.null(tank)) NULL else data.frame(
      session_id=session,camera_id=camera,
      tank_id=tank,treatment=treatment))
}

test_that("movement and three-fish school geometry agree with analytical oracle", {
  x <- make_research_fixture()
  z <- aqt_research_analyze(x$review,
           profiles=c("movement","schooling"),config=list(max_gap_s=.11))
  expect_s3_class(z,"aqt_scientific_analysis")
  expect_equal(z$audit$source_rows,18)
  expect_equal(z$audit$accepted_positions,18)
  expect_true(all(z$diagnostics$status[z$diagnostics$profile %in%
      c("movement","schooling")]=="complete"))
  A <- z$movement$path_summaries
  expect_equal(A$path_length[A$track_id=="0001"],5)
  expect_equal(A$mean_speed[A$track_id=="0001"],10,tolerance=1e-9)
  expect_equal(z$schooling$group_metrics$centroid_x[1L],1)
  expect_equal(z$schooling$group_metrics$centroid_y[1L],1)
  expect_equal(z$schooling$spatial_summary$radius_gyration[1L],2)
  expect_equal(z$schooling$spatial_summary$mean_pair_distance[1L],
    (3+3+sqrt(18))/3,tolerance=1e-10)
  expect_equal(z$schooling$group_metrics$polarization[2L],1,
               tolerance=1e-10)
  expect_true(is.na(z$schooling$group_metrics$polarization[1L]))
  expect_false(z$provenance$fish_identity_certified)
  expect_false(z$provenance$physical_calibration_certified)
  expect_identical(x$review$qc$raw,z$review$qc$raw)
})

test_that("single fish succeeds for movement and skips insufficient schooling", {
  x <- make_research_fixture(nfish=1L)
  z <- aqt_research_analyze(x$review,profiles=c("schooling","movement"))
  expect_equal(z$diagnostics$status[z$diagnostics$profile=="movement"],
               "complete")
  expect_equal(z$diagnostics$status[z$diagnostics$profile=="schooling"],
               "skipped")
  expect_null(z$schooling)
})

test_that("reviewed exclusion cannot reappear in speed, schooling polarization or grids", {
  x <- make_research_fixture(excluded=2)
  z <- aqt_research_analyze(x$review,
      profiles=c("movement","schooling","functional"),
      events=x$events,config=list(max_gap_s=.11,
        event_clock="same_recording",
        functional_grid_s=seq(-.2,.2,by=.1)))
  kin <- z$movement$kinematics
  A <- kin[kin$track_id=="0001",,drop=FALSE]
  expect_true(is.na(A$speed[A$frame_id==2L]))
  expect_true(is.na(A$speed[A$frame_id==3L]))
  expect_equal(A$speed[A$frame_id==4L],10,tolerance=1e-9)
  expect_equal(z$movement$path_summaries$path_length[
    z$movement$path_summaries$track_id=="0001"],3)
  f <- z$functional$grid
  a <- f[f$track_id=="0001",,drop=FALSE]
  expect_false(a$supported[a$time_relative_s==0])
  expect_true(any(!a$supported))
  expect_equal(z$audit$accepted_positions,17)
  expect_equal(z$audit$excluded_rows,1)
  expect_equal(z$schooling$group_metrics$n_visible[3L],2)
})

test_that("recorded event boundaries and descriptive epochs are correct", {
  x <- make_research_fixture(nfish=1L)
  z <- aqt_research_analyze(x$review,
      profiles=c("events","functional"),
      events=x$events,config=list(
        max_gap_s=.11,event_clock="same_recording",
        event_windows=list(baseline=c(-.2,0),response=c(0,.2)),
        functional_grid_s=seq(-.2,.2,by=.1)))
  expect_equal(z$diagnostics$status[z$diagnostics$profile=="events"],
               "complete")
  ep <- z$events$epoch_summaries
  expect_equal(ep$value[ep$epoch=="baseline"],10,tolerance=1e-9)
  expect_equal(ep$value[ep$epoch=="response"],10,tolerance=1e-9)
  expect_true(all(z$functional$coverage$fraction_supported>=0))
  expect_equal(sum(z$functional$grid$supported),5)
  expect_false(z$events$independently_verified_sync)
})

test_that("absence of event clock declaration blocks event and functional models", {
  x <- make_research_fixture(nfish=1L)
  z <- aqt_research_analyze(x$review,profiles=c("events","functional"),
                             events=x$events)
  expect_true(all(z$diagnostics$status[
    z$diagnostics$profile %in% c("events","functional")]=="blocked"))
  expect_null(z$events)
  expect_null(z$functional)
})

test_that("one tank per treatment does not become inferential replication", {
  x <- make_research_fixture(nfish=2L,session="CTRL",tank="C1",
                              treatment="control")
  y <- make_research_fixture(nfish=2L,session="TEST",tank="T1",
                              treatment="treatment")
  raw <- rbind(x$review$qc$raw,y$review$qc$raw)
  frames <- rbind(x$review$qc$frames,y$review$qc$frames)
  q <- aqt_trajectory_qc(raw,frames,max_gap_s=.11)
  z <- aqt_research_analyze(aqt_qc_review(q),profiles="experimental",
         events=rbind(x$events,y$events),
         design=rbind(x$design,y$design),
         config=list(event_clock="same_recording",max_gap_s=.11,
                     experimental_contrast=TRUE,
                     event_windows=list(baseline=c(-.2,0),response=c(0,.2))))
  expect_equal(z$diagnostics$status[
    z$diagnostics$profile=="experimental"],"blocked")
  expect_null(z$statistical_models$tank_contrast)
  expect_true(all(z$statistical_models$design_audit$n_tanks==1L))
})

test_that("unknown original time blocks all timed profiles", {
  x <- make_research_fixture(nfish=1L)
  ff <- x$review$qc$frames; ff$time_s[] <- NA_real_
  raw <- x$review$qc$raw; raw$time_s[] <- NA_real_
  q <- aqt_trajectory_qc(raw,ff)
  z <- aqt_research_analyze(aqt_qc_review(q),
       profiles=c("movement","schooling","events","functional"),
       events=x$events,config=list(event_clock="same_recording"))
  expect_true(all(z$diagnostics$status[z$diagnostics$profile %in%
    z$selected_profiles]=="blocked"))
  expect_null(z$movement); expect_null(z$functional)
  expect_equal(z$audit$source_rows,nrow(raw))
})

test_that("uncertainty is conditional, explicitly configured and reproducible", {
  x <- make_research_fixture(nfish=1L)
  config <- list(max_gap_s=.11,
       uncertainty=list(enabled=TRUE,sigma=.05,draws=20L,seed=11L))
  a <- aqt_research_analyze(x$review,
       profiles=c("movement","uncertainty"),config=config)
  b <- aqt_research_analyze(x$review,
       profiles=c("movement","uncertainty"),config=config)
  expect_identical(a$uncertainty$path_sensitivity,
                   b$uncertainty$path_sensitivity)
  expect_false(a$uncertainty$physical_error_calibrated)
  expect_false(a$uncertainty$path_sensitivity$interval_is_confidence_interval[1L])
  expect_equal(a$uncertainty$n_scenarios,20)
  expect_error(aqt_research_analyze(x$review,profiles="uncertainty",
      config=list(uncertainty=list(enabled=TRUE))),
      "sigma")
})

test_that("analysis export contains no invented results and is checksum-verified", {
  x <- make_research_fixture()
  z <- aqt_research_analyze(x$review,profiles=c("movement","schooling"))
  dest <- tempfile("aqt-science-v1-")
  on.exit(unlink(dest,recursive=TRUE),add=TRUE)
  aqt_research_export(z,dest)
  want <- c("audit/measurement_eligibility.csv",
     "audit/profile_decisions.csv","movement/kinematics.csv",
     "movement/path_summaries.csv","schooling/group_metrics.csv",
     "reproducibility/ANALYSIS_MANIFEST.json",
     "reproducibility/analysis.rds")
  expect_true(all(file.exists(file.path(dest,want))))
  copy <- readRDS(file.path(dest,"reproducibility/analysis.rds"))
  expect_identical(copy$audit$source_sha256,z$audit$source_sha256)
  m <- jsonlite::fromJSON(file.path(dest,
        "reproducibility/ANALYSIS_MANIFEST.json"),simplifyVector=FALSE)
  expect_identical(m$original_raw_sha256,z$audit$source_sha256)
  for (name in names(m$output_sha256)) {
    expect_identical(m$output_sha256[[name]],
       unname(digest::digest(file.path(dest,name),algo="sha256",file=TRUE)))
  }
  expect_error(aqt_research_export(z,dest),"new destination|new")
  expect_identical(z$review$qc$raw,x$review$qc$raw)
})

test_that("unknown config settings and unsupported analyses fail visibly", {
  x <- make_research_fixture()
  expect_error(aqt_research_analyze(x$review,
     config=list(typo_model=TRUE)),"Unknown research config")
  expect_error(aqt_research_analyze(x$review,
     profiles=c("schooling","schooling")),"unique")
  expect_error(aqt_research_analyze(x$review,
     design=data.frame(session_id="S",camera_id="TOP",
                       tank_id="T1",treatment="C",extra=1,
                       stringsAsFactors=FALSE),
     profiles="movement"),NA)
})


test_that("replicated independent tanks permit a declared-direction contrast", {
  assignments <- data.frame(
    session_id=c("C1s","C2s","T1s","T2s"),
    tank_id=c("C1","C2","T1","T2"),
    treatment=c("control","control","treatment","treatment"),
    stringsAsFactors=FALSE)
  parts <- lapply(seq_len(nrow(assignments)),function(i)
    make_research_fixture(nfish=2L,
      session=assignments$session_id[i],
      tank=assignments$tank_id[i],
      treatment=assignments$treatment[i]))
  raw <- do.call(rbind,lapply(parts,function(x) x$review$qc$raw))
  ff <- do.call(rbind,lapply(parts,function(x) x$review$qc$frames))
  ev <- do.call(rbind,lapply(parts,function(x) x$events))
  des <- do.call(rbind,lapply(parts,function(x) x$design))
  review <- aqt_qc_review(aqt_trajectory_qc(raw,ff,max_gap_s=.11))
  common <- list(event_clock="same_recording",max_gap_s=.11,
    event_windows=list(baseline=c(-.2,0),response=c(0,.2)),
    experimental_contrast=TRUE,experimental_draws=100L)
  blocked <- aqt_research_analyze(review,profiles="experimental",
      events=ev,design=des,config=common)
  expect_equal(blocked$diagnostics$status[
      blocked$diagnostics$profile=="experimental"],"blocked")
  expect_match(blocked$diagnostics$reason[
      blocked$diagnostics$profile=="experimental"],"treatment_levels")
  common$treatment_levels <- c("control","treatment")
  study <- aqt_research_analyze(review,
       profiles=c("events","experimental"),events=ev,
       design=des,config=common)
  expect_equal(study$diagnostics$status[
      study$diagnostics$profile=="experimental"],"complete")
  expect_equal(study$statistical_models$tank_contrast$n_tanks_control,2)
  expect_equal(study$statistical_models$tank_contrast$n_tanks_treatment,2)
  expect_equal(study$statistical_models$tank_contrast$estimate,0,tolerance=1e-9)
  expect_false(study$statistical_models$tank_contrast$causal_identification)
  expect_equal(study$statistical_models$tank_contrast$treatment_levels,
               c("control","treatment"))
  expect_equal(study$provenance$coordinate_units,"px")
  expect_error(aqt_research_analyze(review,profiles="experimental",
    events=ev,design=des,
    config=list(treatment_levels=c("control","control"))),
    "distinct|ordered")
})
