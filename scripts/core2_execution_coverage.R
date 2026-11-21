#!/usr/bin/env Rscript
# Optional executed R line/function coverage; lexical source mentions are not coverage.
# Requires covr to be explicitly installed. Never turns missing covr into a PASS.
args <- commandArgs(trailingOnly=TRUE)
if(length(args)!=1L || file.exists(args[[1L]]) || !dir.exists(dirname(args[[1L]])))
  stop("Supply a new evidence directory with existing parent")
if(!requireNamespace("covr",quietly=TRUE))
  stop("Measured execution coverage NOT RUN: install covr first")
if(!requireNamespace("jsonlite",quietly=TRUE))stop("Install jsonlite")
root <- normalizePath(".",mustWork=TRUE)
if(!file.exists(file.path(root,"DESCRIPTION")))stop("Run from package source root")
# covr instruments R package functions and actually executes the package tests.
cvg <- covr::package_coverage(path=root,type="tests",quiet=TRUE)
lines <- as.data.frame(cvg)
if(!nrow(lines))stop("No executed-coverage records were produced")
dir.create(args[[1L]])
utils::write.csv(lines,file.path(args[[1L]],"EXECUTED_COVERAGE.csv"),row.names=FALSE)
rate <- covr::percent_coverage(cvg)
result <- list(schema="AQT_CORE2_EXECUTED_COVERAGE_V1",status="MEASURED",
              percent=as.numeric(rate),n_instrumented_records=nrow(lines),
              source_sha256=unname(digest::digest(file.path(root,"NAMESPACE"),
               file=TRUE,algo="sha256")),
              output_sha256=unname(digest::digest(file.path(args[[1L]],"EXECUTED_COVERAGE.csv"),
               file=TRUE,algo="sha256")),
              physical_biological_validation=FALSE)
jsonlite::write_json(result,file.path(args[[1L]],"EXECUTION_COVERAGE_SUMMARY.json"),
                     pretty=TRUE,auto_unbox=TRUE)
cat("CORE2_EXECUTED_LINE_COVERAGE_MEASURED",round(rate,2),"percent\n")
