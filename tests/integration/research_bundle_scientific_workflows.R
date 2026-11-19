# Native Milestone 03 on actual Python-generated Research Bundle v1 bytes.
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==1L,dir.exists(args[[1L]]))
suppressPackageStartupMessages(library(aquaTrajectories))
root <- args[[1L]]
for(kind in c("mot_bytetrack","mot_botsort","idtracker_tidy","yolo_csv")) {
  raw <- aqt_research_bundle_import(file.path(root,kind,"bundle"))
  stopifnot(raw$output_sha256_verified)
  qc <- aqt_trajectory_qc(raw,max_gap_s=.07)
  r <- aqt_qc_review(qc)
  s <- aqt_research_analyze(r,profiles=c("movement","schooling"),
         config=list(max_gap_s=.07))
  stopifnot(inherits(s,"aqt_scientific_analysis"),
    s$audit$source_rows==nrow(raw$observations),
    s$audit$accepted_positions==r$n_review_eligible,
    identical(s$review$qc$raw,raw$observations),
    identical(s$audit$source_sha256,qc$raw_sha256),
    s$diagnostics$status[s$diagnostics$profile=="movement"]=="complete",
    s$diagnostics$status[s$diagnostics$profile=="schooling"]=="skipped",
    is.null(s$schooling),isFALSE(s$provenance$fish_identity_certified))
  dest <- tempfile(paste0("aqt-study-",kind),tmpdir=root)
  aqt_research_export(s,dest)
  m <- jsonlite::fromJSON(file.path(dest,
    "reproducibility/ANALYSIS_MANIFEST.json"),simplifyVector=FALSE)
  stopifnot(identical(m$original_raw_sha256,qc$raw_sha256),
            file.exists(file.path(dest,"movement/kinematics.csv")))
  for (name in names(m$output_sha256))
    stopifnot(identical(m$output_sha256[[name]],
      unname(digest::digest(file.path(dest,name),algo="sha256",file=TRUE))))
  stopifnot(identical(readRDS(file.path(dest,
      "reproducibility/analysis.rds"))$audit$source_sha256,
      qc$raw_sha256))
}
raw <- aqt_research_bundle_import(file.path(root,"unknown_clock","bundle"))
r <- aqt_qc_review(aqt_trajectory_qc(raw,max_gap_s=.07))
s <- aqt_research_analyze(r,profiles=c("movement","schooling","events","functional"))
stopifnot(all(s$diagnostics$status[s$diagnostics$profile %in%
    s$selected_profiles]=="blocked"),is.null(s$movement),is.null(s$functional),
    identical(s$audit$source_sha256,r$original_source_sha256))
cat("MILESTONE03_PYTHON_TRACKER_BYTES_TO_SCIENTIFIC_R_ANALYSIS: PASS\n")
