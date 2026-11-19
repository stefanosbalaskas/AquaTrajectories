# Direct Python-produced Research Bundle v1 -> R QC -> review -> derived -> report
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==1L,dir.exists(args[1L]))
suppressPackageStartupMessages(library(aquaTrajectories))
root <- args[[1L]]
for(kind in c("mot_bytetrack","mot_botsort","idtracker_tidy","yolo_csv")) {
  source <- aqt_research_bundle_import(file.path(root,kind,"bundle"))
  stopifnot(source$output_sha256_verified)
  audit <- aqt_trajectory_qc(source,max_gap_s=.07)
  stopifnot(nrow(audit$raw)==nrow(source$observations),
            nrow(audit$frames)==3L,
            identical(audit$raw,as.data.frame(source$observations)),
            audit$camera_coverage$n_acquisition_frames==3,
            all(!audit$row_audit$flag_duplicate_identity),
            isFALSE(audit$biological_identity_certified))
  review <- aqt_qc_review(audit)
  stopifnot(inherits(review$tracks,"aqt_tracks"),
            review$n_original==nrow(audit$raw))
  derived <- aqt_qc_derive(review,max_gap_s=.07)
  stopifnot(nrow(derived$kinematics)==nrow(review$tracks),
            derived$summary$n_usable_movements>=0,
            identical(derived$review$original_source_sha256,audit$raw_sha256))
  dest <- tempfile(paste0("aqt-qc-",kind),tmpdir=root)
  aqt_qc_report(review,derived,dest)
  m <- jsonlite::fromJSON(file.path(dest,"QC_REPORT_MANIFEST.json"),
                          simplifyVector=FALSE)
  stopifnot(identical(m$original_source_sha256,audit$raw_sha256),
            file.exists(file.path(dest,"RAW_OBSERVATIONS.csv")),
            file.exists(file.path(dest,"ROW_QUALITY_AUDIT.csv")))
  for (name in names(m$output_sha256))
    stopifnot(identical(m$output_sha256[[name]],
       unname(digest::digest(file.path(dest,name),file=TRUE,algo="sha256"))))
}
unknown <- aqt_research_bundle_import(file.path(root,"unknown_clock","bundle"))
audit <- aqt_trajectory_qc(unknown,max_gap_s=.07)
review <- aqt_qc_review(audit)
stopifnot(is.null(review$tracks),is.null(unknown$tracks),
          all(is.na(audit$frames$time_s)),all(is.na(audit$row_audit$time_s)))
bad <- try(aqt_qc_derive(review),silent=TRUE)
stopifnot(inherits(bad,"try-error"))
cat("AQT_QC_REAL_PYTHON_BYTES_TO_R_AUDIT_PASS: four tracker formats + unknown clock\n")
