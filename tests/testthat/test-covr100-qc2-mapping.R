# Explicit QC 2.0 input boundaries and valid source conversion
# using synthetic trajectories only. Original units and rows are retained.

.cov100_qc2_raw <- function() {
  data.frame(track_id=c("01","01","01"), time_s=c(0,1,2),
    x=c(10,20,30), y=c(20,30,40), stringsAsFactors=FALSE)
}

test_that("QC2 rejects malformed source schemas and inconsistent declarations", {
  d <- .cov100_qc2_raw()
  expect_error(aqt_qc2_report(list(),gap_limits_s=1),"data must be")
  expect_error(aqt_qc2_report("nonexistent_source_xyz.csv",1,units="cm",
          coordinate_system="tank"),"existing CSV")
  expect_error(aqt_qc2_report(d,1,units="unknown",
          coordinate_system="tank"),"Declare source units")
  expect_error(aqt_qc2_report(d,1,units="cm"),
          "Declare coordinate_system")
  expect_error(aqt_qc2_report(d,1,units="cm",
          coordinate_system="tank",target_units="km"),
          "target_units must")
  expect_error(aqt_qc2_report(d,1,units="cm",
          coordinate_system="tank",target_units="px"),"Pixel and physical")
  expect_error(aqt_qc2_report(d,1,units="px",
          coordinate_system="tank"),"Pixel and physical")
  expect_error(aqt_qc2_report(d,1,units="cm",
          coordinate_system="tank",time_scale=Inf),"time_scale")
  expect_error(aqt_qc2_report(d,1,units="cm",
          coordinate_system="tank",time_scale=0),"time_scale")
  expect_error(aqt_qc2_report(d,1,units="cm",
          coordinate_system="tank",column_map=list(x="x")),"column_map must")
  expect_error(aqt_qc2_report(d,1,units="cm",
          coordinate_system="tank",column_map=c(x="x",y="x")),"uniquely map")
  expect_error(aqt_qc2_report(d,1,units="cm",
          coordinate_system="tank",column_map=c(nonexistent="x")),"unsupported canonical")
  expect_error(aqt_qc2_report(d,1,units="cm",
          coordinate_system="tank",column_map=c(track_id="track_id",
                   time_s="time_s",x="x",y="missing")),"missing required mapped")
  bad <- d;bad$time_s <- as.character(bad$time_s)
  expect_error(aqt_qc2_report(bad,1,units="cm",
          coordinate_system="tank"),"Mapped time_s must be numeric")
  bad <- d;bad$x <- as.character(bad$x)
  expect_error(aqt_qc2_report(bad,1,units="cm",
          coordinate_system="tank"),"Mapped coordinates must be numeric")
  bad <- d;bad$observed <- c(1,1,1)
  expect_error(aqt_qc2_report(bad,1,units="cm",
          coordinate_system="tank"),"observed must be nonmissing logical")
  bad <- d;bad$observed <- c(TRUE,FALSE,TRUE)
  expect_error(aqt_qc2_report(bad,1,units="cm",
          coordinate_system="tank"),"observed must agree")
  tr <- aqt_tracks(transform(d,session_id="S",camera_id="C"),
           units="cm",coordinate_system="tank")
  expect_error(aqt_qc2_report(tr,1,units="px"),"fixed columns and units")
  expect_error(aqt_qc2_report(tr,1,time_scale=2),"fixed columns and units")
  expect_error(aqt_qc2_report(tr,1,target_units="m"),"fixed columns and units")
})

test_that("QC2 reports precise conversion, time scale and source identity", {
  d <- .cov100_qc2_raw()
  raw <- serialize(d,NULL)
  cm <- aqt_qc2_report(d,2.1,units="mm",
            coordinate_system="tank",time_scale=.5)
  expect_identical(serialize(d,NULL),raw)
  expect_equal(cm$tracks$x,c(1,2,3),tolerance=1e-12)
  expect_equal(cm$tracks$time_s,c(0,.5,1),tolerance=1e-12)
  expect_identical(cm$source_units,"mm")
  expect_identical(cm$analysis_units,"cm")
  expect_true(all(c("1","2","3") %in% cm$raw_source$source_row))
  meters <- aqt_qc2_report(d,2.1,units="m",target_units="cm",
                    coordinate_system="tank")
  expect_equal(meters$tracks$x,c(1000,2000,3000),tolerance=1e-12)
  mapped <- data.frame(fish_id=c("0007","0007"),t_ms=c(0,1000),
                      u=c(0,10),v=c(0,20),stringsAsFactors=FALSE)
  out <- aqt_qc2_report(mapped,2,units="mm",coordinate_system="tank",
         column_map=c(track_id="fish_id",time_s="t_ms",x="u",y="v"),
         time_scale=.001,session_id="S",camera_id="C")
  expect_identical(unique(out$tracks$track_id),"0007")
  expect_equal(out$tracks$x,c(0,1))
  expect_equal(out$tracks$time_s,c(0,1))
  expect_true(all(nzchar(out$lineage$to_source_row)))
})

test_that("QC2 exported lineages refuse mutated source and scientific evidence", {
  d <- .cov100_qc2_raw()
  out <- aqt_qc2_report(d,2,units="cm",coordinate_system="tank")
  expect_error(aqt_qc2_export(list(),tempfile()),"Expected an aqt_qc2_report")
  dest <- tempfile("cov100_qc2_")
  expect_invisible(aqt_qc2_export(out,dest))
  on.exit(unlink(dest,recursive=TRUE,force=TRUE),add=TRUE)
  expect_true(file.exists(file.path(dest,"QC2_MANIFEST.json")))
  expect_error(aqt_qc2_export(out,dest),"new path")
  copied <- out
  copied$raw_source$x[1] <- -9
  expect_error(aqt_qc2_export(copied,tempfile("qc2_mutation_")),"Original source table")
  copied <- out
  copied$lineage$step_status[2] <- "fabricated"
  expect_error(aqt_qc2_export(copied,tempfile("qc2_ledger_")),"QC scientific evidence")
})

test_that("QC2 evidence export fails closed on staging and atomic rename failures", {
  audited <- aqt_qc2_report(.cov100_qc2_raw(),2,
             units="cm",coordinate_system="tank")
  parent <- tempfile("cov100_qc2_fs_");base::dir.create(parent)
  on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
  first <- file.path(parent,"no-stage")
  testthat::with_mocked_bindings({
    expect_error(aqt_qc2_export(audited,first),
                 "Cannot create QC staging directory")
  },dir.create=function(...) FALSE,.package="aquaTrajectories")
  expect_false(dir.exists(first))
  second <- file.path(parent,"no-commit")
  testthat::with_mocked_bindings({
    expect_error(aqt_qc2_export(audited,second),
                 "Cannot finalize QC 2.0 evidence directory")
  },file.rename=function(...) FALSE,.package="aquaTrajectories")
  expect_false(dir.exists(second))
})
