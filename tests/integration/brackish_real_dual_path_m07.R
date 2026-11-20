#!/usr/bin/env Rscript
# Usage: Rscript --vanilla tests/integration/brackish_real_dual_path_m07.R INPUT_DIR NEW_OUTPUT_DIR
args <- commandArgs(TRUE)
if(length(args)!=2L)stop("Usage: Rscript brackish_real_dual_path_m07.R INPUT_DIR NEW_OUTPUT_DIR")
suppressPackageStartupMessages(library(aquaTrajectories))
input <- args[1L]; output <- args[2L]
require_file <- function(n) {
  path <- file.path(input,n)
  if(!file.exists(path))stop("Missing M07 source input ",n)
  path
}
p <- jsonlite::fromJSON(require_file("M07_PROVENANCE.json"),
                        simplifyVector=FALSE)
stopifnot(identical(p$schema,"AQT_M07_BRACKISH_REAL_FRAME_INDEX_DUAL_PATH_V1"),
  isFALSE(p$biological_identification_certified),
  isFALSE(p$measured_frame_timestamps_supplied),
  identical(p$n_source_frames,868L),
  identical(p$n_reference_rows,6621L),
  identical(p$n_model_track_rows,2830L),
  identical(p$independent_unchanged_source_checks,906L))
for(n in names(p$input_shas)) {
  if(!identical(unname(digest::digest(require_file(n),file=TRUE,
                                     algo="sha256")),p$input_shas[[n]]))
    stop("M07 source input digest changed: ",n)
}
fr <- utils::read.csv(require_file("M07_FRAMES.csv"),
                      stringsAsFactors=FALSE,colClasses=c(data_path="character",
                        session_id="character",camera_id="character"))
obs <- utils::read.csv(require_file("M07_OBSERVATIONS.csv"),
  stringsAsFactors=FALSE,colClasses=c(data_path="character",
    session_id="character",camera_id="character",track_id="character"))
stopifnot(nrow(fr)==1736L,nrow(obs)==9451L,
  setequal(unique(fr$data_path),c("reference","model")),
  all(is.na(fr$time_s)),
  sum(obs$data_path=="reference")==6621L,
  sum(obs$data_path=="model")==2830L)
study <- aqt_frame_index_analyze(fr,obs)
stopifnot(inherits(study,"aqt_frame_index_study"),
  nrow(study$summary)==10L,
  nrow(study$frames)==1736L,
  nrow(study$observations)==9451L,
  all(study$summary$n_recorded_frames>=111L),
  !any(study$metadata$statistical_treatment_inference),
  !any(study$metadata$physical_calibration_validated),
  all(study$observations$step_distance_px[
    is.finite(study$observations$step_distance_px)]>=0),
  all(study$observations$frame_id[
    is.finite(study$observations$step_distance_px)]-
    study$observations$previous_frame_id[
    is.finite(study$observations$step_distance_px)]==1))
# The reference is not compared as if its fish label 1 was the same fish as
# predicted track 1; scopes remain separate in every output.
aqt_frame_index_publish(study,output)
reloaded <- readRDS(file.path(output,"M07_FRAME_INDEX_ANALYSIS.rds"))
stopifnot(identical(reloaded$summary,study$summary))
manifest <- jsonlite::fromJSON(file.path(output,"M07_SCIENCE_MANIFEST.json"),
                               simplifyVector=FALSE)
stopifnot(identical(manifest$schema,"AQT_M07_FRAME_INDEX_SCIENCE_PUBLICATION_V1"),
  isTRUE(manifest$no_measured_clock),
  isFALSE(manifest$reported_physical_speed),
  identical(manifest$n_figures_complete,20L),
  identical(manifest$n_figures_failed,0L),
  file.exists(file.path(output,"REPORT.html")))
for(n in names(manifest$output_sha256))
  stopifnot(identical(unname(digest::digest(file.path(output,n),
                   file=TRUE,algo="sha256")),manifest$output_sha256[[n]]))
cat("M07_REAL_DUAL_PATH_R_REPORT_PASS | reference=6621 model=2830 frame_path_rows=1736 figures=20\n")
