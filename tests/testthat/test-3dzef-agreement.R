# Wave 12A bridge tests are constructed fixtures, not fish accuracy results.
.aqt_zef_agreement_fixture <- function(directory) {
  per_frame <- data.frame(
    frame=1:3,
    truth_count=c(1,1,0),
    prediction_count=c(1,1,1),
    matched_count=c(1,1,0),
    false_positives=c(0,0,1),
    false_negatives=c(0,0,0))
  matches <- data.frame(
    frame=c(1,2),truth_id=c(1,1),predicted_id=c(8,8),
    true_x_cm=c(1,2),true_y_cm=c(2,2),true_z_cm=c(3,3),
    pred_x_cm=c(1.1,2.1),pred_y_cm=c(2,2),pred_z_cm=c(3,3),
    euclidean_error_cm=c(.1,.1))
  utils::write.csv(per_frame,file.path(directory,"per_frame.csv"),
                   row.names=FALSE)
  utils::write.csv(matches,file.path(directory,"matches.csv"),
                   row.names=FALSE)
  names <- c("per_frame.csv","matches.csv")
  sha <- stats::setNames(lapply(names,function(nm)
    unname(digest::digest(file.path(directory,nm),algo="sha256",
                          file=TRUE))),names)
  meta <- list(
    metric_scope="agreement_with_published_3dzef_3d_head_labels",
    source_xyz_unit="cm",
    n_full_video_frames_declared=3L,n_evaluated_frames=3L,
    n_truth_inside_evaluation=2L,n_predictions_inside_evaluation=3L,
    n_matches=2L,false_positives=1L,false_negatives=0L,
    evaluated_frame_fraction=1,
    match_precision=2/3,match_recall=1,
    false_positives_on_declared_empty_frames=1L,
    matched_3d_euclidean_rmse_cm=.1,
    matched_3d_euclidean_mae_cm=.1,
    coordinate_bias_cm_xyz=list(.1,0,0),
    coordinate_rmse_cm_xyz=list(.1,0,0),
    IDTP=2L,IDFP=1L,IDFN=0L,
    adjacent_identity_switches=0L,
    comparable_adjacent_pairs=1L,
    camera_local_3d_IDF1_like=.8,
    association_distance_cutoff_cm=1,
    artifact_sha256=sha,
    independent_physical_xyz_ground_truth_verified=FALSE,
    scientific_accuracy_certified=FALSE,
    official_TrackEval_HOTA_computed=FALSE,
    official_ZF3D_MOTA_computed=FALSE)
  jsonlite::write_json(meta,file.path(directory,"summary.json"),
                       auto_unbox=TRUE,pretty=TRUE,digits=NA)
  list(meta=meta,frames=per_frame,matches=matches)
}

test_that("3D-ZeF handoff checks counts, geometry, scope and SHA-256", {
  p <- tempfile("zef-")
  dir.create(p)
  on.exit(unlink(p,recursive=TRUE),add=TRUE)
  fixture <- .aqt_zef_agreement_fixture(p)
  z <- aqt_3dzef_agreement_import(p)
  expect_s3_class(z,"aqt_3dzef_label_agreement")
  expect_true(z$software_integrity_verified)
  expect_false(z$physical_underwater_xyz_accuracy_certified)
  expect_equal(nrow(z$matches),2L)
  expect_equal(z$summary$n_matches,2L)
  expect_error(aqt_3dzef_agreement_import(tempfile("absent-")),
               "existing agreement output")
  utils::write.csv(transform(fixture$frames,matched_count=c(0,0,0)),
                   file.path(p,"per_frame.csv"),row.names=FALSE)
  expect_error(aqt_3dzef_agreement_import(p),"SHA-256")
})

test_that("3D-ZeF import rejects internally inconsistent but rehashed evidence", {
  p <- tempfile("zef-")
  dir.create(p)
  on.exit(unlink(p,recursive=TRUE),add=TRUE)
  fixture <- .aqt_zef_agreement_fixture(p)
  corrupted <- fixture$matches
  corrupted$euclidean_error_cm[1] <- .99
  utils::write.csv(corrupted,file.path(p,"matches.csv"),row.names=FALSE)
  meta <- fixture$meta
  meta$artifact_sha256[["matches.csv"]] <-
    unname(digest::digest(file.path(p,"matches.csv"),
                          algo="sha256",file=TRUE))
  jsonlite::write_json(meta,file.path(p,"summary.json"),
                       auto_unbox=TRUE,pretty=TRUE,digits=NA)
  expect_error(aqt_3dzef_agreement_import(p),
               "matched distance exceeds reported geometry")
  corrupted <- fixture$matches
  utils::write.csv(corrupted,file.path(p,"matches.csv"),row.names=FALSE)
  meta$artifact_sha256[["matches.csv"]] <-
    unname(digest::digest(file.path(p,"matches.csv"),
                          algo="sha256",file=TRUE))
  meta$scientific_accuracy_certified <- TRUE
  jsonlite::write_json(meta,file.path(p,"summary.json"),
                       auto_unbox=TRUE,pretty=TRUE,digits=NA)
  expect_error(aqt_3dzef_agreement_import(p),
               "Incomplete or overclaimed")
})


test_that("original Python scorer produces files accepted by native R audit", {
  python <- Sys.which("python3")
  if (!nzchar(python)) skip("Python 3 unavailable on this machine")
  runner <- system.file("python","aqt_3dzef_agreement.py",
                        package="aquaTrajectories")
  expect_true(nzchar(runner))
  tmp <- tempfile("zef-real-roundtrip-")
  dir.create(tmp)
  on.exit(unlink(tmp,recursive=TRUE),add=TRUE)
  gt <- file.path(tmp,"truth.txt")
  pred <- file.path(tmp,"pred.txt")
  manifest <- file.path(tmp,"evaluated.csv")
  output <- file.path(tmp,"results")
  writeLines(c("1,1,1,2,3","2,1,2,2,3"),gt)
  writeLines(c("1,8,1.1,2,3","2,8,2.1,2,3","3,9,7,8,9"),pred)
  writeLines(c("frame,review_status","1,fully_annotated",
               "2,fully_annotated","3,fully_annotated"),manifest)
  args <- c(shQuote(runner),"--truth",shQuote(gt),
            "--predictions",shQuote(pred),
            "--evaluated-frames",shQuote(manifest),
            "--frame-count","3","--threshold-cm","1",
            "--output-dir",shQuote(output))
  log <- suppressWarnings(system2(unname(python),args=args,
                                  stdout=TRUE,stderr=TRUE))
  expect_true(is.null(attr(log,"status")) ||
              identical(as.integer(attr(log,"status")),0L),
              info=paste(log,collapse="\n"))
  expect_true(file.exists(file.path(output,"summary.json")),
              info=paste(log,collapse="\n"))
  imported <- aqt_3dzef_agreement_import(output)
  expect_true(imported$software_integrity_verified)
  expect_equal(imported$summary$n_matches,2)
  expect_equal(imported$summary$false_positives,1)
  expect_equal(imported$summary$matched_3d_euclidean_rmse_cm,.1,
               tolerance=1e-8)
  expect_false(imported$summary$scientific_accuracy_certified)
})
