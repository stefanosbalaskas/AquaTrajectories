#!/usr/bin/env Rscript
# Original real-data numerical parity check; no source data is committed to GitHub.
# Usage: Rscript scripts/m08_real_reference_parity.R INPUT_M07_DIR PYTHON_M08_DIR NEW_OUTPUT_DIR
args <- commandArgs(trailingOnly=TRUE)
if(length(args)!=3L)stop("Expected input, independent Python benchmark, new R report output")
input <- normalizePath(args[[1L]],mustWork=TRUE)
py <- normalizePath(args[[2L]],mustWork=TRUE)
out <- args[[3L]]
if(file.exists(out))stop("Refuse overwriting previous R validation evidence")
if(!dir.exists(dirname(out)))stop("R report parent does not exist")
suppressPackageStartupMessages(library(aquaTrajectories))
frames <- utils::read.csv(file.path(input,"M07_FRAMES.csv"),stringsAsFactors=FALSE)
obs <- utils::read.csv(file.path(input,"M07_OBSERVATIONS.csv"),stringsAsFactors=FALSE)
matched <- utils::read.csv(file.path(py,"tables","M08_MATCHED_OBSERVATIONS.csv"),
                            stringsAsFactors=FALSE)
pyresults <- jsonlite::fromJSON(file.path(py,"M08_SCIENTIFIC_RESULTS.json"),simplifyVector=TRUE)
stopifnot(identical(pyresults$schema,"AQT_M08_REFERENCE_CONDITIONAL_MEASUREMENT_V1"),
          identical(pyresults$primary_iou,0.5),
          nrow(frames)==1736L,nrow(obs)==9451L,nrow(matched)==374L)
# Record source hashes independently, without modifying the original data.
prov <- jsonlite::fromJSON(file.path(input,"M07_PROVENANCE.json"),simplifyVector=TRUE)
for(n in names(prov$input_shas)) {
  got <- unname(digest::digest(file.path(input,n),file=TRUE,algo="sha256"))
  stopifnot(identical(got,prov$input_shas[[n]]))
}
study <- aqt_reference_measurement_validate(frames,obs,matched,iou_threshold=.5)
ref <- pyresults$by_sequence
r <- study$summary
if(!setequal(ref$sequence,r$sequence))stop("Real sequence scope mismatch")
ref <- ref[match(r$sequence,ref$sequence),,drop=FALSE]
# Exactly 13 independent comparisons x 5 original source sequences.
mapping <- c("n_reference"="n_reference","n_model"="n_model",
 "n_matched"="n_matched",
 "n_reference_adjacent_steps"="n_reference_adjacent_steps",
 "n_paired_same_id_steps"="n_paired_same_id_steps",
 "n_two_endpoints_different_model_id"="n_two_endpoints_different_model_id",
 "n_reference_steps_missing_match_endpoint"="n_reference_steps_missing_match_endpoint",
 "median_position_error_px"="median_position_error_px",
 "paired_step_MAE_px"="paired_step_MAE_px",
 "frames_with_two_or_more_matched"="frames_with_two_or_more_matched",
 "matched_group_rg_MAE_px"="matched_group_rg_MAE_px",
 "group_subset_selection_rg_MAE_px"="group_subset_selection_rg_MAE_px",
 "paired_step_fraction"="paired_step_coverage")
ledger <- list();j <- 0L
for(i in seq_len(nrow(r)))for(n in names(mapping)) {
  actual <- as.numeric(r[[n]][i])
  expected <- as.numeric(ref[[mapping[[n]]]][i])
  same <- if(is.na(actual)||is.na(expected))is.na(actual)&&is.na(expected) else
    is.finite(actual)&&is.finite(expected)&&
    abs(actual-expected)<=1e-7*max(1,abs(actual),abs(expected))
  j <- j+1L
  ledger[[j]] <- data.frame(sequence=r$sequence[i],metric=n,
    native_R=actual,independent_Python=expected,pass=same)
  if(!same)stop("Native R/source-Python mismatch: ",r$sequence[i],"/",n)
}
stopifnot(j==65L,all(vapply(ledger,function(x)x$pass,logical(1L))),
  sum(r$n_reference)==6621L,sum(r$n_model)==2830L,
  sum(r$n_matched)==374L,sum(r$n_reference_adjacent_steps)==6498L,
  sum(r$n_paired_same_id_steps)==265L)
aqt_reference_measurement_publish(study,out)
summary <- do.call(rbind,ledger)
utils::write.csv(summary,file.path(dirname(out),"M08_R_PYTHON_PARITY_65.csv"),
                 row.names=FALSE,na="")
record <- list(schema="AQT_M08_REAL_R_PYTHON_REFERENCE_PARITY_V1",
    status="PASS",n_comparisons=j,n_sequences=nrow(r),
    original_source_observations=nrow(obs),
    n_publisher_reference=sum(r$n_reference),
    n_model_tracker_rows=sum(r$n_model),
    n_reference_matched=sum(r$n_matched),
    n_reference_adjacent_steps=sum(r$n_reference_adjacent_steps),
    n_identity_continuous_paired_steps=sum(r$n_paired_same_id_steps),
    physical_3D_biological_ID_and_welfare_certified=FALSE,
    original_m07_provenance_sha256=unname(digest::digest(
      file.path(input,"M07_PROVENANCE.json"),file=TRUE,algo="sha256")))
record_path <- file.path(dirname(out),"M08_REAL_R_PYTHON_PARITY.json")
if(file.exists(record_path))stop("Refuse overwriting existing native parity JSON")
jsonlite::write_json(record,record_path,pretty=TRUE,auto_unbox=TRUE)
cat("M08_REAL_NATIVE_R_PYTHON_PARITY_PASS",j,"comparisons",nrow(r),"sequences\n")
