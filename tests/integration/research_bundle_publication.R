# Python-emitted source bytes -> native R QC -> M03 -> actual M04 vector report.
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==1L,dir.exists(args[[1L]]))
suppressPackageStartupMessages(library(aquaTrajectories))
root <- args[[1L]]
for(kind in c("mot_bytetrack","mot_botsort","idtracker_tidy","yolo_csv")) {
  input <- aqt_research_bundle_import(file.path(root,kind,"bundle"))
  stopifnot(input$output_sha256_verified)
  review <- aqt_qc_review(aqt_trajectory_qc(input,max_gap_s=.07))
  science <- aqt_research_analyze(review,
                  profiles=c("movement","schooling"),
                  config=list(max_gap_s=.07))
  plan <- aqt_research_figure_plan(science)
  stopifnot(plan$eligible[plan$kind=="coverage"],
            plan$eligible[plan$kind=="review_counts"],
            plan$eligible[plan$kind=="paths"],
            plan$eligible[plan$kind=="speed"],
            !plan$eligible[plan$kind=="school_dispersion"])
  output <- tempfile(paste0("pub_",kind,"_"),tmpdir=root)
  aqt_research_publish(science,output,formats="pdf",
    width=5.8,height=4.3,data_origin="synthetic")
  catalog <- utils::read.csv(file.path(output,"FIGURE_CATALOG.csv"),
                             stringsAsFactors=FALSE)
  stopifnot(!any(catalog$status=="failed"),
            catalog$status[catalog$kind=="school_dispersion"]=="skipped",
            file.exists(file.path(output,"figures/F01_SOURCE_COVERAGE.pdf")),
            identical(readBin(file.path(output,
             "figures/F01_SOURCE_COVERAGE.pdf"),"raw",4),
             charToRaw("%PDF")))
  output_analysis <- readRDS(file.path(output,
      "analysis/reproducibility/analysis.rds"))
  stopifnot(identical(output_analysis$audit$source_sha256,
                      review$original_source_sha256))
  manifest <- jsonlite::fromJSON(file.path(output,
      "PUBLICATION_MANIFEST.json"),simplifyVector=FALSE)
  stopifnot(identical(manifest$original_raw_sha256,
                      review$original_source_sha256))
  for (file in names(manifest$output_sha256))
    stopifnot(identical(manifest$output_sha256[[file]],
      unname(digest::digest(file.path(output,file),file=TRUE,algo="sha256"))))
}
missing <- aqt_research_bundle_import(file.path(root,"unknown_clock","bundle"))
review <- aqt_qc_review(aqt_trajectory_qc(missing,max_gap_s=.07))
science <- aqt_research_analyze(review,profiles=c("movement","schooling"))
plan <- aqt_research_figure_plan(science)
stopifnot(!plan$eligible[plan$kind=="paths"],
          !plan$eligible[plan$kind=="speed"])
out <- tempfile("pub_no_clock_",tmpdir=root)
aqt_research_publish(science,out,formats="pdf",data_origin="synthetic")
stopifnot(!file.exists(file.path(out,"figures/S01_MEASURED_SPEED.pdf")),
          file.exists(file.path(out,"figures/F02_REVIEW_COUNTS.pdf")))
cat("M04_PYTHON_BYTES_TO_R_PUBLICATION: PASS (4 trackers + unknown clock)\n")
