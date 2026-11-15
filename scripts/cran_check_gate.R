#!/usr/bin/env Rscript
# Strict CRAN check result gate. The first-submission feasibility NOTE is
# expected and must be disclosed, never hidden or manufactured.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L || !file.exists(args[[1L]]))
  stop("Provide an existing 00check.log", call. = FALSE)
lines <- readLines(args[[1L]], warn = FALSE, encoding = "UTF-8")
status <- grep("^Status: ", lines, value = TRUE)
checks <- grep("^\\* checking .*\\.\\.\\. (NOTE|WARNING|ERROR)$", lines, value = TRUE)
if (length(status) != 1L) {
  cat("Check summaries: ", paste(status, collapse = "; "), "\n")
  stop("Cannot establish unique R CMD check status", call. = FALSE)
}
expected <- "* checking CRAN incoming feasibility ... NOTE"
allowed <- length(checks) == 1L && identical(checks[[1L]], expected) &&
  any(trimws(lines) == "New submission") &&
  identical(status[[1L]], "Status: 1 NOTE")
clean <- length(checks) == 0L && identical(status[[1L]], "Status: OK")
if (!allowed && !clean) {
  cat("Unexpected CRAN check sections:\n", paste(checks, collapse = "\n"),
      "\nSummary: ", status[[1L]], "\n")
  stop("CRAN source check is not submission-ready", call. = FALSE)
}
cat(if (allowed)
      "CRAN_CHECK_PASS_WITH_EXPECTED_FIRST_SUBMISSION_NOTE\n"
    else "CRAN_CHECK_PASS_ZERO_NOTES\n")
