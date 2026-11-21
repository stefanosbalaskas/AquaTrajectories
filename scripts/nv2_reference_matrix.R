#!/usr/bin/env Rscript
# NV2 fail-closed reference matrix. Only mark PASS after ACTUAL testthat calls
# return success. This is numerical software validation on synthetic fixtures,
# not independent empirical truth for fish IDs or XYZ calibration.
args<-commandArgs(trailingOnly=TRUE)
if(length(args)!=1L || file.exists(args[[1L]]) ||
   !dir.exists(dirname(args[[1L]])))
  stop("Provide a NEW evidence directory under existing parent")
suppressPackageStartupMessages(library(aquaTrajectories))
if(!requireNamespace("testthat",quietly=TRUE) ||
   !requireNamespace("nlme",quietly=TRUE) ||
   !requireNamespace("fdapace",quietly=TRUE))
  stop("Full NV2 certification requires testthat, nlme and fdapace")
domains<-data.frame(
 method=c("kinematics","school_geometry","DTW","recurrence","HMM",
          "FPCA_dense","hierarchical_inference","conditional_uncertainty",
          "FPCA_sparse"),
 tested_export=c("aqt_kinematics;aqt_path_summary",
   "aqt_group_metrics;aqt_group_spatial_summary",
   "aqt_trajectory_dtw","aqt_trajectory_recurrence",
   "aqt_hmm_decode","aqt_trajectory_grid_pca",
   "aqt_hierarchical_event_fit",
   "aqt_trajectory_ensemble;aqt_ensemble_summarize",
   "aqt_sparse_fpca_input;aqt_sparse_fpca_fit"),
 external_oracle=c("manual vector finite differences",
    "pairwise Euclidean distances and vector normalization",
    "exhaustively enumerated alignment paths",
    "manually indexed recurrence matrix and line runs",
    "exhaustively enumerated state sequences",
    "base-R SVD on independently assembled grid",
    "direct nlme ML fit and balanced fish-level difference-in-differences",
    "zero-error exact reference and stats quantiles",
    "independent temporal support counts and direct fdapace output"),
 metamorphic=c("translation and 90-degree isometry",
   "fish-ID relabelling and group translation",
   "symmetry, translation, scaling",
   "spatial translation invariance",
   "joint emission/model location shift",
   "translated paths with start centering",
   "nested fish-ID relabelling",
   "zero-noise path identity and RNG isolation",
   "affine source-time rescaling"),
 negative_case=c("duplicate time and invalid gap",
   "invalid minimum group size","window too narrow; unobserved path",
   "negative radius; missing samples",
   "invalid stochastic transition; short interrupted run",
   "unobserved curve","insufficient independent tanks",
   "invalid rho; duplicated draw","insufficient samples; sparse support"),
 stringsAsFactors=FALSE)
test_path<-"tests/testthat/test-nv2-oracles.R"
sparse_path<-"tests/testthat/test-nv2-sparse-fpca.R"
population_path<-"tests/testthat/test-nv2-sparse-population.R"
if(!file.exists(test_path)||!file.exists(sparse_path)||
   !file.exists(population_path))
  stop("Source oracle files absent")
src<-paste(readLines(test_path,warn=FALSE),collapse="\n")
for(name in paste0("NV2_",c("KINEMATICS","GROUP","DTW","RECURRENCE",
                           "HMM","FPCA","HIERARCHICAL","UNCERTAINTY")))
  if(!grepl(name,src,fixed=TRUE))stop("Reference method absent: ",name)
testthat::test_file(test_path,reporter="summary",stop_on_failure=TRUE)
testthat::test_file(sparse_path,reporter="summary",stop_on_failure=TRUE)
testthat::test_file(population_path,reporter="summary",stop_on_failure=TRUE)
# Previously established independent oracles and external backend checks
# remain first-class regression checks, rather than only new test mentions.
testthat::test_file("tests/testthat/test-priority-a-independent-references.R",
                   reporter="summary",stop_on_failure=TRUE)
testthat::test_file("tests/testthat/test-priority-a-backend-agreement.R",
                   reporter="summary",stop_on_failure=TRUE)
testthat::test_file("tests/testthat/test-priority-a-optics-uncertainty-references.R",
                   reporter="summary",stop_on_failure=TRUE)
domains$oracle_status<-"PASS_EXECUTED"
domains$metamorphic_status<-"PASS_EXECUTED"
domains$negative_case_status<-"PASS_EXECUTED"
domains$independent_real_data_accuracy_certified<-FALSE
dir.create(args[[1L]])
file<-file.path(args[[1L]],"NV2_REFERENCE_MATRIX.csv")
utils::write.csv(domains,file,row.names=FALSE)
meta<-list(schema="NV2_REFERENCE_MATRIX_V1",
  n_scientific_domains=nrow(domains),
  method_scope=domains$method,
  numerical_validation_status="PASS_SYNTHETIC_REFERENCE_CHECKS",
  backend_agreement_not_independent_estimator_implementation=TRUE,
  real_biological_accuracy_certified=FALSE,
  source_sha256=as.list(stats::setNames(vapply(
    c(test_path,sparse_path,population_path),function(f)
      unname(digest::digest(f,file=TRUE,algo="sha256")),
    character(1L)),c(basename(test_path),basename(sparse_path),basename(population_path)))),
  matrix_sha256=unname(digest::digest(file,file=TRUE,algo="sha256")),
  package_version=as.character(utils::packageVersion("aquaTrajectories")),
  R_version=as.character(getRversion()),
  backend_versions=list(nlme=as.character(utils::packageVersion("nlme")),
                        fdapace=as.character(utils::packageVersion("fdapace"))))
jsonlite::write_json(meta,file.path(args[[1L]],"NV2_REFERENCE_MANIFEST.json"),
                     pretty=TRUE,auto_unbox=TRUE)
cat("NV2_REFERENCE_MATRIX_PASS",nrow(domains),
    "domains (independent numerical known-answer and failure tests)\n")
