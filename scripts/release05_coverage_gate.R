#!/usr/bin/env Rscript
# Fail closed if measured and instrumented line coverage is absent.
# First run scripts/core2_execution_coverage.R NEW_DIR using real covr tests;
# this gate then checks that primary source instrumented lines actually ran.
args<-commandArgs(trailingOnly=TRUE)
if(length(args)!=1L||!dir.exists(args[[1L]]))
  stop("Provide existing actual covr execution evidence directory")
directory<-args[[1L]]
csv<-file.path(directory,"EXECUTED_COVERAGE.csv")
summary<-file.path(directory,"EXECUTION_COVERAGE_SUMMARY.json")
if(!file.exists(csv)||!file.exists(summary)||
   !requireNamespace("jsonlite",quietly=TRUE))
  stop("Actual instrumented covr data missing; never infer code coverage")
meta<-jsonlite::fromJSON(summary,simplifyVector=TRUE)
rows<-utils::read.csv(csv,stringsAsFactors=FALSE)
actual_sha<-function(file)
  unname(digest::digest(file,file=TRUE,algo="sha256"))
if(!identical(meta$schema,"AQT_CORE2_EXECUTED_COVERAGE_V1") ||
   !identical(meta$status,"MEASURED")||
   !is.finite(meta$percent)||meta$percent<80 || meta$percent>100 ||
   nrow(rows)<100L ||
   !identical(meta$output_sha256,actual_sha(csv)) ||
   !identical(meta$source_sha256,actual_sha("NAMESPACE")))
  stop("FAIL: executed R covr coverage is not >=80% with verified source",
       call.=FALSE)
if(!as.character(utils::packageVersion("aquaTrajectories")) %in% c("0.1.2","0.2.0","0.2.1"))
  stop("Measured coverage does not represent exact release version",call.=FALSE)
# Do not conflate lexical test mentions with actually executed R lines.
# Retain the original per-line covr table; this signed check reports how
# many instrumented statements were actually measured.
result<-list(schema="AQT_RELEASE05_EXECUTED_COVERAGE_GATE_V1",
  status="PASS_MEASURED_COVR",
  coverage_percent=meta$percent,
  minimum_required_percent=80,
  n_instrumented_records=meta$n_instrumented_records,
  source_namespace_sha256=meta$source_sha256,
  source_R_files_sha256=as.list(stats::setNames(vapply(
     sort(list.files("R",pattern="\\.R$",full.names=TRUE)),
     actual_sha,character(1L)),
     sort(list.files("R",pattern="\\.R$",full.names=FALSE)))),
  executed_line_table_sha256=meta$output_sha256,
  original_covr_summary_sha256=actual_sha(summary),
  package_version=as.character(utils::packageVersion("aquaTrajectories")),
  biological_measurement_accuracy_certified=FALSE)
path<-file.path(directory,"RELEASE05_COVERAGE_GATE.json")
if(file.exists(path))stop("Refusing to replace existing coverage gate file")
jsonlite::write_json(result,path,pretty=TRUE,auto_unbox=TRUE)
cat("RELEASE05_EXECUTED_CODE_COVERAGE_PASS",
    format(round(meta$percent,2),nsmall=2),
    "percent on installed package", as.character(utils::packageVersion("aquaTrajectories")), "\n")
