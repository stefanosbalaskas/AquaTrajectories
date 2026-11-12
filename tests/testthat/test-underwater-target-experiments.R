.aqt_target_experiment_fixture <- function() {
  n <- 18L
  xyz <- cbind(
    x=seq(-.2,.8,length.out=n),
    y=.25*sin(seq_len(n)*1.3),
    z=seq(.5,1.9,length.out=n))
  cam <- function(cx) aqt_flatport_camera(
    diag(3),diag(3),c(cx,0,-1),c(0,0,0),c(0,0,1),
    glass_thickness=.1,n_first=1,n_glass=1,
    n_water=1,units="cm")
  pix <- function(cx) cbind((xyz[,1]-cx)/(xyz[,3]+1),
                            xyz[,2]/(xyz[,3]+1))
  a <- pix(-1);bb <- pix(1)
  single <- function(trial,tank) data.frame(
    trial_id=trial,tank_id=tank,session_id=paste0("S_",trial),
    camera_a_id="TOP",camera_b_id="SIDE",
    target_id=paste0("L",seq_len(n)),
    target_group=c(rep("BOARD_FIT",12),rep("BOARD_HOLDOUT",6)),
    partition=c(rep("fit",12),rep("holdout",6)),
    truth_x=xyz[,1],truth_y=xyz[,2],truth_z=xyz[,3],
    a_u_px=a[,1],a_v_px=a[,2],
    b_u_px=bb[,1],b_v_px=bb[,2])
  list(
    data=rbind(single("A","tank1"),single("B","tank2")),
    models=list(TOP=cam(-1),SIDE=cam(1)))
}

test_that("holdout benchmark scores independent target groups without fit leakage", {
  fixture <- .aqt_target_experiment_fixture()
  trials <- aqt_target_trial_table(fixture$data,units="cm")
  expect_s3_class(trials,"aqt_target_trials")
  expect_false(attr(trials,"aqt_external_xyz_survey_verified"))
  expect_false(attr(trials,"aqt_calibration_certified"))
  expect_identical(attr(trials,"aqt_pixel_contract"),
                   "externally_undistorted_image_pixels")
  score <- aqt_target_holdout_benchmark(trials,fixture$models)
  expect_s3_class(score,"aqt_target_holdout_audit")
  expect_equal(score$summary$n_trials,2)
  expect_equal(score$summary$n_tanks,2)
  expect_equal(score$summary$n_heldout_targets,12)
  expect_equal(score$summary$n_valid,12)
  expect_equal(score$summary$n_invalid,0)
  expect_equal(score$summary$valid_fraction,1)
  expect_true(all(score$per_trial$n_fit_targets==12))
  expect_true(all(score$per_trial$n_holdout_targets==6))
  expect_lt(max(score$per_trial$rmse_3d),1e-8)
  expect_lt(score$summary$pooled_target_rmse_3d,1e-8)
  expect_true(all(score$per_target$partition=="holdout"))
  expect_true(all(score$per_target$landmark_id %in%
       paste0("L",13:18)))
  expect_false(score$real_underwater_metrology_certified)
  expect_false(score$source_xyz_survey_verified)
  expect_true(score$training_target_groups_not_scored)
  expect_true(score$independence_requires_external_collection)
})

test_that("heldout failed triangulations count against valid fraction", {
  fixture <- .aqt_target_experiment_fixture()
  d <- fixture$data
  d$b_v_px[d$trial_id=="A" & d$target_id=="L13"] <-
    d$b_v_px[d$trial_id=="A" & d$target_id=="L13"]+.7
  trials <- aqt_target_trial_table(d)
  score <- aqt_target_holdout_benchmark(
    trials,fixture$models,max_ray_separation=1e-7)
  expect_equal(score$summary$n_heldout_targets,12)
  expect_lt(score$summary$n_valid,12)
  expect_equal(score$summary$n_invalid,
               12-score$summary$n_valid)
  expect_true(any(!score$per_target$valid))
})

test_that("calibration target registry refuses leaked and degenerate benchmarks", {
  fixture <- .aqt_target_experiment_fixture()
  d <- fixture$data
  expect_error(aqt_target_trial_table(
    transform(d,partition="fit")),">=6 fit and >=3")
  same_board <- d
  same_board$target_group[same_board$target_id=="L13"] <- "BOARD_FIT"
  expect_error(aqt_target_trial_table(same_board),
               "target assemblies must be disjoint")
  duplicated <- d
  duplicated$target_id[18] <- duplicated$target_id[17]
  expect_error(aqt_target_trial_table(duplicated),
               "Duplicate physical target")
  invalid <- d
  invalid$camera_a_id[1] <- "OTHER"
  expect_error(aqt_target_trial_table(invalid),
               "fixed camera pair")
  no_depth <- d
  no_depth$truth_z[no_depth$partition=="holdout"] <- 1
  expect_error(aqt_target_trial_table(no_depth),
               "depth variation")
  absent <- d
  absent$a_u_px[1] <- NA_real_
  expect_error(aqt_target_trial_table(absent),
               "finite numeric")
  expect_error(aqt_target_trial_table(d,units="pixels"),
               "arg")
})

test_that("auditor refuses missing camera models and incompatible physical units", {
  fixture <- .aqt_target_experiment_fixture()
  d <- aqt_target_trial_table(fixture$data)
  plain <- d
  class(plain) <- "data.frame"
  expect_error(aqt_target_holdout_benchmark(
    plain,fixture$models),
    "Expected aqt_target_trials")
  expect_error(aqt_target_holdout_benchmark(
    d,list(TOP=fixture$models$TOP,SIDE=fixture$models$TOP)),
    "physically distinct camera centres")
  expect_error(aqt_target_holdout_benchmark(
    d,list(TOP=fixture$models$TOP)),
    "named refractive camera models")
  d2 <- d
  d2$camera_b_id[d2$trial_id=="B"] <- "OTHER"
  class(d2) <- class(d)
  attr(d2,"aqt_units") <- "cm"
  expect_error(aqt_target_holdout_benchmark(
    d2,fixture$models),"Missing camera model")
  wrong_units <- aqt_target_trial_table(fixture$data,units="m")
  expect_error(aqt_target_holdout_benchmark(
    wrong_units,fixture$models),
    "units must match")
})

test_that("modifying calibration-fit pixels never contaminates heldout XYZ scores", {
  fixture <- .aqt_target_experiment_fixture()
  base <- aqt_target_holdout_benchmark(
    aqt_target_trial_table(fixture$data),fixture$models)
  modified <- fixture$data
  modified$a_u_px[modified$partition=="fit"] <-
    modified$a_u_px[modified$partition=="fit"]+5
  modified$b_v_px[modified$partition=="fit"] <-
    modified$b_v_px[modified$partition=="fit"]-2
  test <- aqt_target_holdout_benchmark(
    aqt_target_trial_table(modified),fixture$models)
  expect_equal(test$per_target$error_3d,base$per_target$error_3d)
  expect_equal(test$per_trial$rmse_3d,base$per_trial$rmse_3d)
  expect_equal(test$summary$pooled_target_rmse_3d,
               base$summary$pooled_target_rmse_3d)
  expect_equal(test$summary$n_heldout_targets,12)
})
