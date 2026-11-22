# Research workflow configuration and inferential-scope fault tests.
# All source frames and experimental assignments are synthetic.

.cov100_research_review <- function() {
  f <- data.frame(session_id="S",camera_id="C",frame_id=0:5,
    time_s=(0:5)/10,width_px=100,height_px=80)
  d <- data.frame(session_id="S",camera_id="C",
    frame_id=rep(0:5,2),time_s=rep((0:5)/10,2),
    track_id=rep(c("001","002"),each=6),
    x=c(10:15,20:25),y=c(rep(10,6),rep(20,6)),
    observed=TRUE,detection_confidence=.95)
  q <- aqt_trajectory_qc(d,f,max_gap_s=.11)
  list(review=aqt_qc_review(q),
       events=data.frame(session_id="S",event_id="E",start_s=.3,end_s=.3),
       design=data.frame(session_id="S",camera_id="C",tank_id="T",
                         treatment="control"))
}

test_that("research config fails closed on malformed parameters and conditional requests", {
  fn <- aquaTrajectories:::.aqt_research_config
  tests <- list(
    list(config=1,pattern="named list"),
    list(config=list(1),pattern="named list"),
    list(config=list(unrecognized=TRUE),pattern="Unknown research config"),
    list(config=list(min_visible_fish=1L),pattern="min_visible_fish must"),
    list(config=list(max_pairs=0L),pattern="max_pairs must"),
    list(config=list(event_min_points=0L),pattern="event_min_points must"),
    list(config=list(event_clock="device_time"),pattern="event_clock"),
    list(config=list(event_outcome="welfare"),pattern="Event outcome"),
    list(config=list(event_estimator="median"),pattern="Invalid event estimator"),
    list(config=list(functional_model="unknown"),pattern="functional_model"),
    list(config=list(experimental_contrast=NA),pattern="Model requests"),
    list(config=list(functional_contrast=1),pattern="Model requests"),
    list(config=list(treatment_levels=c("control","control")),pattern="treatment_levels"),
    list(config=list(treatment_levels="control"),pattern="treatment_levels"),
    list(config=list(experimental_contrast=TRUE,experimental_draws=99L),
         pattern="experimental_draws must"),
    list(config=list(functional_contrast=TRUE,experimental_draws=5001L),
         pattern="functional contrast draws"),
    list(config=list(functional_grid_s=c(1,1)),pattern="functional_grid_s"),
    list(config=list(functional_grid_s=0),pattern="functional_grid_s"),
    list(config=list(min_fish_fraction=0),pattern="min_fish_fraction"),
    list(config=list(min_fish_fraction=1.1),pattern="min_fish_fraction"),
    list(config=list(uncertainty=c(TRUE,FALSE)),pattern="uncertainty must"),
    list(config=list(uncertainty=list(unknown=2)),pattern="Unknown uncertainty"),
    list(config=list(uncertainty=list(enabled=NA)),pattern="uncertainty enabled"),
    list(config=list(uncertainty=list(enabled=TRUE)),pattern="requires researcher-declared sigma"),
    list(config=list(uncertainty=list(enabled=TRUE,sigma=.1,draws=19L)),
         pattern="Uncertainty draws"),
    list(config=list(uncertainty=list(enabled=TRUE,sigma=.1,draws=1001L)),
         pattern="Uncertainty draws")
  )
  for (t in tests) expect_error(fn(t$config),t$pattern,info=paste(t$pattern,collapse=" "))
  okay <- fn(list(event_clock="same_recording",
     functional_grid_s=seq(-.2,.2,by=.1),
     uncertainty=list(enabled=TRUE,sigma=.1,draws=20L)))
  expect_true(okay$uncertainty$enabled)
  expect_equal(okay$event_estimator,"time_weighted")
})

test_that("independent tank design mapping cannot invent or duplicate acquisition scopes", {
  tr <- aqt_tracks(data.frame(session_id="S",camera_id="C",
    track_id="01",time_s=0:2,x=0:2,y=0:2))
  d <- data.frame(session_id="S",camera_id="C",
       tank_id="T",treatment="control")
  design <- aquaTrajectories:::.aqt_research_design
  expect_null(design(NULL,tr))
  expect_error(design(data.frame(x=1),tr),"Design requires")
  bad <- d;bad$tank_id <- ""
  expect_error(design(bad,tr),"Design contains blank")
  expect_error(design(rbind(d,d),tr),"exactly one design row")
  bad <- d;bad$camera_id <- "unrecorded"
  expect_error(design(bad,tr),"exactly the review recording scopes")
  out <- design(d,tr)
  expect_equal(out$tank_id,"T")
  attach <- aquaTrajectories:::.aqt_research_attach_design
  expect_identical(attach(data.frame(x=1),NULL),data.frame(x=1))
  expect_error(attach(data.frame(session_id="S",camera_id="MISSING"),
                      d),"Design mapping lost")
  attached <- attach(data.frame(session_id="S",camera_id="C"),d)
  expect_identical(attached$tank_id,"T")
  model_try <- aquaTrajectories:::.aqt_research_model_try
  expect_true(model_try(function() 3)$ok)
  expect_false(model_try(function() stop("synthetic failure"))$ok)
  expect_match(model_try(function() stop("synthetic failure"))$error,"synthetic failure")
})

test_that("workflow audit blocks unknown profiles, unreviewed source and unsupported contrasts", {
  x <- .cov100_research_review()
  expect_error(aqt_research_analyze(NULL),"valid source-preserving")
  expect_error(aqt_research_analyze(x$review,profiles="unregistered"),"six workflow")
  expect_error(aqt_research_analyze(x$review,profiles=c("events","events")),"six workflow")
  bad <- x$review
  bad$qc$raw$x[1] <- -999
  expect_error(aqt_research_analyze(bad),"valid source-preserving")
  missing_events <- aqt_research_analyze(x$review,
                  profiles=c("events","functional","experimental"),
                  config=list(event_clock="same_recording"))
  expect_true(all(missing_events$diagnostics$status[
    missing_events$diagnostics$profile %in% missing_events$selected_profiles] ==
     "blocked"))
  no_clock <- aqt_research_analyze(x$review,profiles="events",events=x$events)
  expect_identical(no_clock$diagnostics$status[
     no_clock$diagnostics$profile=="events"],"blocked")
  no_repeat <- aqt_research_analyze(x$review,profiles="experimental",
      events=x$events,design=x$design,
      config=list(event_clock="same_recording",
        event_windows=list(baseline=c(-.2,0),response=c(0,.2)),
        event_min_points=1L,experimental_contrast=TRUE,
        treatment_levels=c("control","treatment")))
  expect_identical(no_repeat$diagnostics$status[
     no_repeat$diagnostics$profile=="experimental"],"blocked")
  # A single tank is an observational container, not replicated treatment.
  expect_false(no_repeat$provenance$fish_identity_certified)
  expect_false(no_repeat$provenance$physical_calibration_certified)
})

test_that("scientific-analysis export preserves source hashes and refuses tampering", {
  x <- .cov100_research_review()
  z <- aqt_research_analyze(x$review,profiles="movement")
  expect_error(aqt_research_export(list(),tempfile()),"Unverifiable scientific")
  parent <- tempfile("cov100_study_")
  dir.create(parent)
  on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
  dest <- file.path(parent,"analysis")
  expect_invisible(aqt_research_export(z,dest))
  expect_true(file.exists(file.path(dest,
     "reproducibility/ANALYSIS_MANIFEST.json")))
  expect_true(file.exists(file.path(dest,"movement/kinematics.csv")))
  expect_error(aqt_research_export(z,dest),"new destination")
  tampered <- z
  tampered$review$qc$raw$x[1] <- -123
  expect_error(aqt_research_export(tampered,file.path(parent,"bad")),
        "Unverifiable scientific")
})

test_that("scientific analysis atomic export failure preserves original review and source hash", {
  x <- .cov100_research_review()
  result <- aqt_research_analyze(x$review,profiles="movement")
  raw_sha <- result$review$original_source_sha256
  parent <- tempfile("cov100_scientific_fs_");base::dir.create(parent)
  on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
  dest <- file.path(parent,"noncommitted")
  testthat::with_mocked_bindings({
    expect_error(aqt_research_export(result,dest),
                 "Unable to publish complete scientific analysis output")
  },file.rename=function(...) FALSE,.package="aquaTrajectories")
  expect_false(dir.exists(dest))
  expect_identical(result$review$original_source_sha256,raw_sha)
})
