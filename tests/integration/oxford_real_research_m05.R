# Full real Oxford video evidence -> imported Research Bundle -> R QC/M03/M04.
args <- commandArgs(trailingOnly=TRUE)
if(length(args)!=3L) stop("Require real bundle, source audit and new output")
bundle_dir <- args[[1L]]
audit_file <- args[[2L]]
output <- args[[3L]]
if (!dir.exists(bundle_dir) || !file.exists(audit_file) ||
    dir.exists(output) || file.exists(output))
  stop("Real input files required and destination must be new")

suppressPackageStartupMessages(library(aquaTrajectories))
source <- jsonlite::fromJSON(audit_file,simplifyVector=FALSE)
stopifnot(identical(source$schema,
      "AQT_M05_REAL_OXFORD_DEVELOPMENT_DEMONSTRATION_V1"),
  identical(source$source_clip_sha256,
      "acd118909b7bd44b013450e35525409ab2bfe53e15e81f48834fe33bfea682c0"),
  as.integer(source$full_original_source_frames)==149L,
  isFALSE(source$new_session_independent_holdout),
  isFALSE(source$source_labels_prediction_blind_independently_verified),
  isFALSE(source$fish_id_accuracy_HOTA_IDF1_certified))

bundle <- aqt_research_bundle_import(bundle_dir)
stopifnot(inherits(bundle,"aqt_research_bundle"),
  isTRUE(bundle$output_sha256_verified),
  identical(bundle$metadata$time_status,"source_pts"),
  nrow(bundle$frames)==149L,nrow(bundle$observations)>0L,
  identical(unique(bundle$frames$session_id),"oxford_eval"),
  identical(unique(bundle$frames$camera_id),"oxford_single_video"),
  all(is.finite(bundle$frames$time_s)),
  identical(as.numeric(bundle$frames$frame_id),as.numeric(0:148)),
  nrow(bundle$observations)==as.integer(
    source$n_native_model_generated_bytetrack_observations))

qc <- aqt_trajectory_qc(bundle,max_gap_s=.15)
reviewed <- aqt_qc_review(qc)
stopifnot(identical(qc$raw,bundle$observations),
  isFALSE(qc$biological_identity_certified),
  reviewed$n_manual_decisions==0L)
study <- aqt_research_analyze(reviewed,
    profiles=c("movement","schooling","events","functional",
               "experimental","uncertainty"),
    config=list(max_gap_s=.15))
stopifnot(inherits(study,"aqt_scientific_analysis"),
  is.list(study$movement),
  identical(study$review$qc$raw,qc$raw),
  identical(study$audit$source_sha256,qc$raw_sha256),
  !study$provenance$fish_identity_certified,
  !study$provenance$physical_calibration_certified,
  !study$provenance$event_clock_independently_certified)

steps <- sum(is.finite(study$movement$kinematics$step_distance))
if(steps<1L)
  stop("Actual original tracking recording lacks usable movement steps")
if(any(study$diagnostics$status[study$diagnostics$profile %in%
        c("events","functional","experimental")]!="blocked"))
  stop("Missing actual event log must BLOCK event and treatment inference")

dir.create(output)
on.exit(if(dir.exists(output) &&
     !file.exists(file.path(output,"M05_SUCCESS.json")))
     unlink(output,recursive=TRUE,force=TRUE),add=TRUE)
dir.create(file.path(output,"source_evidence"))
stopifnot(file.copy(audit_file,file.path(output,"source_evidence",
                                         "REAL_SOURCE_AUDIT.json")))
aqt_research_publish(study,file.path(output,"publication"),
    formats=c("png","pdf"),dpi=300L,max_scopes=1L,data_origin="real")

paths <- study$movement$path_summaries
kin <- study$movement$kinematics
stopifnot(all(kin$speed[is.finite(kin$speed)]>=0),
          all(paths$path_length>=0))
status <- study$diagnostics[,c("profile","status","reason","n_used"),
                             drop=FALSE]
utils::write.csv(status,file.path(output,"PROFILE_STATUS.csv"),
                 row.names=FALSE,na="")
utils::write.csv(paths,file.path(output,"REAL_OBSERVED_PATH_SUMMARY.csv"),
                 row.names=FALSE,na="")
catalog <- utils::read.csv(
  file.path(output,"publication","FIGURE_CATALOG.csv"),
  stringsAsFactors=FALSE)
if(any(catalog$status=="failed"))
  stop("Actual real study has failed plotted figures")
manifest <- jsonlite::fromJSON(file.path(output,"publication",
                      "PUBLICATION_MANIFEST.json"),simplifyVector=FALSE)
stopifnot(identical(manifest$original_raw_sha256,study$audit$source_sha256),
          identical(manifest$declared_data_origin,"real"),
          isFALSE(manifest$independent_data_origin_verified))
for (file in names(manifest$output_sha256))
  stopifnot(identical(manifest$output_sha256[[file]],
    unname(digest::digest(file.path(output,"publication",file),
                          algo="sha256",file=TRUE))))
if(!file.exists(file.path(output,"publication","figures",
                          "S01_QUALIFIED_PATHS.png")) ||
   !file.exists(file.path(output,"publication","figures",
                          "S01_MEASURED_SPEED.pdf")))
  stop("Source-supported real movement figures missing")

results <- list(
  schema="AQT_M05_REAL_OXFORD_RESEARCH_RESULTS_V1",
  source="Oxford original 149-frame aquarium F30_T15.mp4",
  original_source_clip_sha256=source$source_clip_sha256,
  source_archive_sha256=source$source_archive_sha256,
  frozen_model="Oxford EfficientDet-D2 v2 (not YOLO)",
  tracker="original genuine ByteTrack",
  previous_original_model_run_id=source$archived_real_inference_run_id,
  new_model_inference_performed_during_handoff=FALSE,
  n_source_frames=as.integer(nrow(bundle$frames)),
  n_raw_real_tracking_observations=as.integer(nrow(bundle$observations)),
  n_review_eligible_observations=as.integer(study$audit$accepted_positions),
  n_review_excluded_observations=as.integer(study$audit$excluded_rows),
  n_eligible_frame_adjacent_movements=as.integer(steps),
  spatial_units="px",speed_units="px/s",
  video_local_PTS_reverified=TRUE,
  original_source_review_labels_prediction_blind=FALSE,
  independently_certified_fish_ID_accuracy=FALSE,
  freshly_untouched_session_independent_holdout=FALSE,
  physical_calibration_certified=FALSE,
  external_intervention_event_times_supplied=FALSE,
  stress_welfare_or_causality_reported=FALSE,
  schooling_profile=as.character(status$status[
      status$profile=="schooling"]),
  source_review_detector_agreement_not_blind_independent_accuracy=
    source$original_scoring_against_source_reviewed_boxes,
  n_complete_figures=as.integer(sum(catalog$status=="complete")),
  n_withheld_figures=as.integer(sum(catalog$status=="skipped")),
  original_observations_sha256=study$audit$source_sha256,
  publication_manifest_sha256=unname(digest::digest(
      file.path(output,"publication","PUBLICATION_MANIFEST.json"),
      algo="sha256",file=TRUE)))
jsonlite::write_json(results,file.path(output,"REAL_STUDY_RESULTS.json"),
    pretty=TRUE,auto_unbox=TRUE,na="null",null="null",digits=17)

readme <- c(
 "# AquaTrajectories Milestone 05 - real Oxford fish-video research demonstration",
 "",
 "Original real Oxford 149-frame fish-tank MP4, checked against its original",
 "source SHA-256 and re-probed video-local presentation timestamps.",
 "",
 "Model: Oxford frozen EfficientDet-D2 v2, not YOLO; genuine ByteTrack.",
 paste("Original model inference was carried out in prior GitHub run",
       source$archived_real_inference_run_id,"and re-used intact here."),
 "This handoff does not claim to have performed new model inference.",
 "",
 paste("Original acquisition frames:",nrow(bundle$frames)),
 paste("Source-generated tracked observations:",nrow(bundle$observations)),
 paste("Quality eligible tracked positions:",study$audit$accepted_positions),
 paste("Valid consecutive-frame movement intervals:",steps),
 "",
 "Original time units are seconds from MP4 video-local PTS. Original",
 "image spatial units are pixels; observed speeds are pixels/second.",
 "",
 "The complete AQT workflow ran: Research Bundle v1, automatic QC review,",
 "R movement/schooling as supported, actual vector PDF/PNG publication",
 "graphics and numeric tables, all chained to immutable source hashes.",
 "",
 "LIMITATIONS:",
 "- This previously exposed video is not a newly untouched independent session.",
 "- Oxford reviewed labels may have originated with the same original model.",
 "  Agreement against them does not establish blinded detection accuracy.",
 "- No independently annotated full fish-ID oracle. No official HOTA/IDF1.",
 "- No underwater metric calibration or real XYZ in this recording.",
 "- No independent feeding/stress/enrichment event log; event models blocked.",
 "- No independent treatment tanks or causal comparisons.",
 "- No biological stress, welfare, species, or fixed biological identity claims.",
 "",
 "Source evidence: source_evidence/REAL_SOURCE_AUDIT.json",
 "Exact empirical measurements: REAL_STUDY_RESULTS.json",
 "Per-profile status and reasons: PROFILE_STATUS.csv",
 "Original QC and computed full analysis: publication/analysis/",
 "Figures and manuscript captions: publication/figures/ and publication/REPORT.md",
 "All downstream hashes: publication/PUBLICATION_MANIFEST.json",
 "Video files and detector weights are not duplicated in these outputs.",
 ""
)
writeLines(readme,file.path(output,"README_REAL_FISH_STUDY.md"))
jsonlite::write_json(list(status="PASS",
    original_source_frames=149L,
    actual_source_tracker_observations=as.integer(nrow(bundle$observations)),
    frame_adjacent_movement_steps=as.integer(steps),
    published_file_sha256_verified=TRUE,
    independent_identity_accuracy_certified=FALSE,
    untouched_session_holdout_certified=FALSE),
    file.path(output,"M05_SUCCESS.json"),auto_unbox=TRUE,pretty=TRUE)
cat("M05_REAL_OXFORD_TO_AQT_R_PUBLICATION: PASS\n")
cat("Real source frames:",nrow(bundle$frames),"\n")
cat("Real tracker observations:",nrow(bundle$observations),"\n")
cat("QC-eligible displacement intervals:",steps,"\n")
cat("Figures:",sum(catalog$status=="complete"),
  "published,",sum(catalog$status=="skipped"),"withheld\n")
cat("No independent biological identity or fresh-session claim\n")
