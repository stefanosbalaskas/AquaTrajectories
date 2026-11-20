#!/usr/bin/env Rscript
# Standalone local execution against original M06-verified canonical M07 tables.
# Does not need a GitHub merge or package reinstall for these two functions.
args <- commandArgs(TRUE)
if(length(args)!=3L)stop("Usage: Rscript run_m07_native.R TOOLKIT_ROOT INPUT_DIR NEW_OUTPUT_DIR")
root <- args[1L]; input <- args[2L]; output <- args[3L]
for(pkg in c("jsonlite","digest"))
  if(!requireNamespace(pkg,quietly=TRUE))
    stop(pkg," must be installed in the user's R environment")
source(file.path(root,"R","frame-index-research.R"),local=.GlobalEnv,
       encoding="UTF-8")
require_input <- function(name) {
  p <- file.path(input,name)
  if(!file.exists(p))stop("Missing source data: ",name)
  p
}
p <- jsonlite::fromJSON(require_input("M07_PROVENANCE.json"),
                        simplifyVector=FALSE)
if(!identical(p$schema,"AQT_M07_BRACKISH_REAL_FRAME_INDEX_DUAL_PATH_V1") ||
   isTRUE(p$biological_identification_certified) ||
   isTRUE(p$measured_frame_timestamps_supplied))
  stop("Wrong or time-invented source provenance")
for(n in names(p$input_shas))
  if(!identical(unname(digest::digest(require_input(n),
                                     file=TRUE,algo="sha256")),
                p$input_shas[[n]]))
    stop("Source SHA-256 mismatch: ",n)
fr <- utils::read.csv(require_input("M07_FRAMES.csv"),
  stringsAsFactors=FALSE,colClasses=c(data_path="character",
    session_id="character",camera_id="character"))
obs <- utils::read.csv(require_input("M07_OBSERVATIONS.csv"),
  stringsAsFactors=FALSE,colClasses=c(data_path="character",
    session_id="character",camera_id="character",track_id="character"))
if(nrow(fr)!=1736L || nrow(obs)!=9451L ||
   sum(obs$data_path=="reference")!=6621L ||
   sum(obs$data_path=="model")!=2830L)
  stop("Real M07 source denominator mismatch")
a <- aqt_frame_index_analyze(fr,obs)
aqt_frame_index_publish(a,output)
stopifnot(file.exists(file.path(output,"M07_SCIENCE_MANIFEST.json")),
  nrow(a$summary)==10L,
  !any(is.finite(a$observations$step_distance_px) &
       (a$observations$frame_id-a$observations$previous_frame_id!=1L)))
cat("M07_NATIVE_R_REAL_FRAME_SCIENCE_PASS: 868 frames * 2 paths, 9451 source observations, 20 paired scientific figures\n")
