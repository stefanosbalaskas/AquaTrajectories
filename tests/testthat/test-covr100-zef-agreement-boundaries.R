# Explicit synthetic 3D-ZeF agreement mutation tests. No fish model, 3D
# ground truth or physical calibration is assumed or distributed.

.cov100_zef_source <- function() {
  p <- tempfile("cov100_zef_")
  dir.create(p)
  frame <- data.frame(frame=1:3,truth_count=c(1,1,0),
     prediction_count=c(1,1,1),matched_count=c(1,1,0),
     false_positives=c(0,0,1),false_negatives=c(0,0,0))
  matches <- data.frame(frame=c(1,2),truth_id=c(1,1),
     predicted_id=c(8,8),
     true_x_cm=c(1,2),true_y_cm=c(2,2),true_z_cm=c(3,3),
     pred_x_cm=c(1.1,2.1),pred_y_cm=c(2,2),pred_z_cm=c(3,3),
     euclidean_error_cm=c(.1,.1))
  meta <- list(metric_scope="agreement_with_published_3dzef_3d_head_labels",
     source_xyz_unit="cm",n_full_video_frames_declared=3L,
     n_evaluated_frames=3L,n_truth_inside_evaluation=2L,
     n_predictions_inside_evaluation=3L,n_matches=2L,
     false_positives=1L,false_negatives=0L,
     evaluated_frame_fraction=1,
     match_precision=2/3,match_recall=1,
     false_positives_on_declared_empty_frames=1L,
     matched_3d_euclidean_rmse_cm=.1,
     matched_3d_euclidean_mae_cm=.1,
     coordinate_bias_cm_xyz=list(.1,0,0),
     coordinate_rmse_cm_xyz=list(.1,0,0),
     IDTP=2L,IDFP=1L,IDFN=0L,adjacent_identity_switches=0L,
     comparable_adjacent_pairs=1L,camera_local_3d_IDF1_like=.8,
     association_distance_cutoff_cm=1,artifact_sha256=list(),
     independent_physical_xyz_ground_truth_verified=FALSE,
     scientific_accuracy_certified=FALSE,official_TrackEval_HOTA_computed=FALSE,
     official_ZF3D_MOTA_computed=FALSE)
  list(root=p,frames=frame,matches=matches,meta=meta)
}

.cov100_zef_seal <- function(b) {
  utils::write.csv(b$frames,file.path(b$root,"per_frame.csv"),row.names=FALSE)
  utils::write.csv(b$matches,file.path(b$root,"matches.csv"),row.names=FALSE)
  for(nm in c("per_frame.csv","matches.csv"))
    b$meta$artifact_sha256[[nm]] <- unname(digest::digest(
      file.path(b$root,nm),file=TRUE,algo="sha256"))
  jsonlite::write_json(b$meta,file.path(b$root,"summary.json"),
                       auto_unbox=TRUE,pretty=TRUE,digits=NA,null="null")
  b
}

.cov100_zef_reject <- function(transform,pattern) {
  b <- .cov100_zef_source()
  on.exit(unlink(b$root,recursive=TRUE,force=TRUE),add=TRUE)
  b <- transform(b)
  b <- .cov100_zef_seal(b)
  testthat::expect_error(aqt_3dzef_agreement_import(b$root),pattern)
}

test_that("3D-ZeF importer checks existing files and metadata independently", {
  p <- tempfile("cov100_zef_empty_")
  dir.create(p)
  on.exit(unlink(p,recursive=TRUE,force=TRUE),add=TRUE)
  expect_error(aqt_3dzef_agreement_import(p),"Missing 3D-ZeF")
  .cov100_zef_reject(function(b){
    names(b$frames)[1] <- "wrong_frame";b
  },"column schema")
  .cov100_zef_reject(function(b){
    b$meta$n_matches <- -1L;b
  },"Invalid 3D-ZeF summary count")
  .cov100_zef_reject(function(b){
    b$meta$n_evaluated_frames <- 4L;b
  },"frame or match counts mismatch")
  .cov100_zef_reject(function(b){
    b$frames$frame[2] <- 1;b
  },"Duplicate or out-of-range")
  .cov100_zef_reject(function(b){
    b$frames$frame[1] <- 0;b
  },"Invalid 3D-ZeF field")
  .cov100_zef_reject(function(b){
    b$frames$matched_count[1] <- 0;b
  },"Inconsistent ZF3D frame accounting")
})

test_that("3D-ZeF validates matching identity, geometry and per-frame consistency", {
  .cov100_zef_reject(function(b){
    b$matches$true_x_cm[1] <- NA_real_;b
  },"Invalid 3D-ZeF matched coordinates")
  .cov100_zef_reject(function(b){
    b$matches$frame[1] <- 99;b
  },"Repeated or out-of-scope")
  .cov100_zef_reject(function(b){
    b$matches$frame[2] <- 1
    b$matches$truth_id[2] <- 2
    b$matches$predicted_id[2] <- 9
    b
  },"per-frame match rows")
  .cov100_zef_reject(function(b){
    b$meta$evaluated_frame_fraction <- .75;b
  },"Inconsistent 3D-ZeF summary metric")
  .cov100_zef_reject(function(b){
    b$meta$coordinate_bias_cm_xyz <- list(.1,0);b
  },"Incomplete matched 3D-ZeF axis metrics")
  .cov100_zef_reject(function(b){
    b$meta$IDTP <- 3L;b
  },"Inconsistent 3D-ZeF identity denominators")
  .cov100_zef_reject(function(b){
    b$meta$camera_local_3d_IDF1_like <- .5;b
  },"Inconsistent 3D-ZeF summary metric")
})

test_that("empty agreement denominator requires explicit undefined metrics", {
  base <- .cov100_zef_source()
  on.exit(unlink(base$root,recursive=TRUE,force=TRUE),add=TRUE)
  base$frames$truth_count[] <- 0L
  base$frames$prediction_count[] <- 0L
  base$frames$matched_count[] <- 0L
  base$frames$false_positives[] <- 0L
  base$frames$false_negatives[] <- 0L
  base$matches <- base$matches[0,,drop=FALSE]
  base$meta$n_truth_inside_evaluation <- 0L
  base$meta$n_predictions_inside_evaluation <- 0L
  base$meta$n_matches <- 0L
  base$meta$false_positives <- 0L
  base$meta$false_negatives <- 0L
  base$meta$match_precision <- NULL
  base$meta$match_recall <- NULL
  base$meta$false_positives_on_declared_empty_frames <- 0L
  base$meta$matched_3d_euclidean_rmse_cm <- NULL
  base$meta$matched_3d_euclidean_mae_cm <- NULL
  base$meta$IDTP <- 0L
  base$meta$IDFP <- 0L
  base$meta$IDFN <- 0L
  base$meta$adjacent_identity_switches <- 0L
  base$meta$comparable_adjacent_pairs <- 0L
  base$meta$camera_local_3d_IDF1_like <- NULL
  base <- .cov100_zef_seal(base)
  valid <- aqt_3dzef_agreement_import(base$root)
  expect_s3_class(valid,"aqt_3dzef_label_agreement")
  expect_equal(nrow(valid$matches),0L)
  expect_false(valid$physical_underwater_xyz_accuracy_certified)
  mutated <- base
  mutated$meta$match_precision <- 0
  .cov100_zef_seal(mutated)
  expect_error(aqt_3dzef_agreement_import(base$root),"Undefined match precision")
  mutated$meta$match_precision <- NULL
  mutated$meta$match_recall <- 0
  .cov100_zef_seal(mutated)
  expect_error(aqt_3dzef_agreement_import(base$root),"Undefined match recall")
  mutated$meta$match_recall <- NULL
  mutated$meta$matched_3d_euclidean_rmse_cm <- 0
  .cov100_zef_seal(mutated)
  expect_error(aqt_3dzef_agreement_import(base$root),"Empty match set requires")
  mutated$meta$matched_3d_euclidean_rmse_cm <- NULL
  mutated$meta$camera_local_3d_IDF1_like <- 0
  .cov100_zef_seal(mutated)
  expect_error(aqt_3dzef_agreement_import(base$root),"Undefined IDF1-like")
})

test_that("3D-ZeF does not silently accept source frames claiming absent match rows",{
  b <- .cov100_zef_source()
  on.exit(unlink(b$root,recursive=TRUE,force=TRUE),add=TRUE)
  b$matches <- b$matches[FALSE,,drop=FALSE]
  b <- .cov100_zef_seal(b)
  expect_error(aqt_3dzef_agreement_import(b$root),
               "3D-ZeF agreement frame or match counts mismatch")
})
test_that("3D-ZeF rejects mathematically impossible negative identity totals",{
  .cov100_zef_reject(function(b){
    b$meta$IDTP <- -1L
    b
  },"Invalid 3D-ZeF identity metric: IDTP")
})
