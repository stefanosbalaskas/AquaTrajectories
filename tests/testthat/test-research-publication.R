# Entirely synthetic publishing contract regression tests.
# These examples demonstrate software operation, NOT real fish tracking.

publication_fixture <- function(nfish=3L,unknown_clock=FALSE,
                                include_events=TRUE,
                                do_uncertainty=FALSE) {
  ff <- data.frame(session_id="S01",camera_id="TOP",
      frame_id=0:5,time_s=(0:5)/10,
      width_px=100,height_px=80)
  if(unknown_clock)ff$time_s[] <- NA_real_
  fish <- lapply(seq_len(nfish),function(id) {
    data.frame(session_id="S01",camera_id="TOP",
      track_id=sprintf("%04d",id),frame_id=0:5,
      time_s=if(unknown_clock)rep(NA_real_,6) else (0:5)/10,
      x=if(id<3L) 0:5 else rep(3,6),
      y=if(id==2L)rep(3,6) else rep(0,6),
      observed=TRUE,
      detection_confidence=rep(.95,6),stringsAsFactors=FALSE)
  })
  data <- do.call(rbind,fish)
  rownames(data) <- NULL
  r <- aqt_qc_review(aqt_trajectory_qc(data,ff,max_gap_s=.11))
  events <- if(include_events)data.frame(session_id="S01",
    event_id="feeding",start_s=.3,end_s=.3) else NULL
  cfg <- list(max_gap_s=.11)
  selected <- c("movement","schooling")
  if(include_events && !unknown_clock) {
    cfg$event_clock <- "same_recording"
    cfg$event_windows <- list(baseline=c(-.2,0),
                              response=c(0,.2))
    cfg$functional_grid_s <- seq(-.2,.2,by=.1)
    selected <- c(selected,"events","functional")
  }
  if(do_uncertainty) {
    cfg$uncertainty <- list(enabled=TRUE,sigma=.05,
                            draws=20L,seed=11L)
    selected <- c(selected,"uncertainty")
  }
  aqt_research_analyze(r,profiles=selected,
                       events=events,config=cfg)
}

test_that("figure plan exposes every withheld plot and deterministic scope ID", {
  study <- publication_fixture(nfish=1L,include_events=FALSE)
  a <- aqt_research_figure_plan(study)
  b <- aqt_research_figure_plan(study)
  expect_identical(a,b)
  expect_true(a$eligible[a$kind=="paths"])
  expect_true(a$eligible[a$kind=="speed"])
  expect_false(a$eligible[a$kind=="school_dispersion"])
  expect_false(a$eligible[a$kind=="tank_changes"])
  expect_true(all(nzchar(a$reason[!a$eligible])))
  expect_false(anyDuplicated(a$figure_id)>0)
  expect_error(aqt_research_figure_plan(study,max_scopes=0),"1 to 8")
  expect_identical(study$audit$source_sha256,
     digest::digest(study$review$qc$raw,algo="sha256",serialize=TRUE))
})

test_that("a full synthetic study renders real figures without refitting models", {
  study <- publication_fixture(nfish=3L,do_uncertainty=TRUE)
  before <- serialize(study,NULL,version=3L)
  plan <- aqt_research_figure_plan(study)
  expected <- c("coverage","review_counts","paths","speed",
                "school_dispersion","polarization","event_epochs",
                "functional_support","functional_curves","sensitivity")
  expect_true(all(expected %in% plan$kind[plan$eligible]))
  out <- tempfile("aqt-pub-m04-")
  on.exit(unlink(out,recursive=TRUE,force=TRUE),add=TRUE)
  aqt_research_publish(study,out,formats=c("png","pdf"),
      dpi=125L,width=6.6,height=4.8,data_origin="synthetic")
  want <- c("REPORT.md","FIGURE_CATALOG.csv",
      "PUBLICATION_MANIFEST.json",
      "analysis/reproducibility/analysis.rds",
      "analysis/reproducibility/ANALYSIS_MANIFEST.json",
      "tables/T01_QC_COUNTS.csv","tables/T04_INDIVIDUAL_MOVEMENT.csv",
      "figures/F01_SOURCE_COVERAGE.png",
      "figures/F01_SOURCE_COVERAGE.pdf")
  expect_true(all(file.exists(file.path(out,want))))
  catalog <- utils::read.csv(file.path(out,"FIGURE_CATALOG.csv"),
      stringsAsFactors=FALSE)
  expect_false(any(catalog$status=="failed"))
  expect_equal(sum(catalog$status=="complete"),sum(plan$eligible))
  expect_true(all(catalog$status[catalog$kind=="tank_changes"]=="skipped"))
  listed <- list.files(file.path(out,"figures"),full.names=TRUE)
  expect_equal(length(listed),2*sum(plan$eligible))
  expect_true(all(file.info(listed)$size>400))
  png <- file.path(out,"figures/F01_SOURCE_COVERAGE.png")
  pdf <- file.path(out,"figures/F01_SOURCE_COVERAGE.pdf")
  expect_identical(readBin(png,what="raw",n=8),
      as.raw(c(137,80,78,71,13,10,26,10)))
  expect_identical(rawToChar(readBin(pdf,what="raw",n=4)),"%PDF")
  manifest <- jsonlite::fromJSON(file.path(out,"PUBLICATION_MANIFEST.json"),
      simplifyVector=FALSE)
  expect_identical(manifest$original_raw_sha256,
                   study$audit$source_sha256)
  expect_identical(manifest$declared_data_origin,"synthetic")
  expect_false(manifest$independent_data_origin_verified)
  expect_equal(manifest$n_figures_complete,sum(plan$eligible))
  for(path in names(manifest$output_sha256))
    expect_identical(manifest$output_sha256[[path]],
       unname(digest::digest(file.path(out,path),file=TRUE,algo="sha256")))
  report <- paste(readLines(file.path(out,"REPORT.md"),warn=FALSE),
                  collapse="\n")
  expect_match(report,"NOT",ignore.case=FALSE)
  expect_match(report,"Declared data origin: synthetic")
  expect_match(report,study$audit$source_sha256)
  expect_identical(before,serialize(study,NULL,version=3L))
  expect_error(aqt_research_publish(study,out),"new")
})

test_that("unknown timestamps produce quality figures but no synthetic movement", {
  study <- publication_fixture(nfish=1L,unknown_clock=TRUE,
                               include_events=FALSE)
  plan <- aqt_research_figure_plan(study)
  expect_true(all(plan$eligible[plan$kind %in%
                    c("coverage","review_counts")]))
  expect_false(any(plan$eligible[plan$kind %in%
                   c("paths","speed","school_dispersion")]))
  out <- tempfile("aqt-pub-no-clock-")
  on.exit(unlink(out,recursive=TRUE,force=TRUE),add=TRUE)
  aqt_research_publish(study,out,formats="pdf",
                        data_origin="unspecified")
  catalog <- utils::read.csv(file.path(out,"FIGURE_CATALOG.csv"))
  expect_true(all(catalog$status[catalog$kind %in%
              c("paths","speed","school_dispersion")]=="skipped"))
  expect_false(file.exists(file.path(out,
                   "figures/S01_MEASURED_SPEED.pdf")))
  expect_true(file.exists(file.path(out,
                   "figures/F01_SOURCE_COVERAGE.pdf")))
  output <- readRDS(file.path(out,"analysis/reproducibility/analysis.rds"))
  expect_null(output$movement)
})

test_that("missing-frame breaks survive publication and source tables are identical", {
  study <- publication_fixture(nfish=1L,include_events=FALSE)
  study$review$row_audit$manual_decision[1L] <- "test_tamper"
  expect_error(aqt_research_publish(study,tempfile("tamper-")),
      "source-verified|intact",fixed=FALSE)
})

test_that("publication validates formats and dimensions before writing", {
  study <- publication_fixture()
  expect_error(aqt_research_publish(study,tempfile("badfmt-"),
                    formats=c("png","png")),"unique")
  expect_error(aqt_research_publish(study,tempfile("badwidth-"),
                    width=2),"3..15")
  expect_error(aqt_research_publish(study,tempfile("baddpi-"),
                    dpi=70),"100..600")
})
