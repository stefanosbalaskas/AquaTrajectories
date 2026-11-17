# Analytical software qualification. No real biological accuracy is inferred.
test_that("existing CSV preserves IDs and matches hand-calculated paths", {
  x <- data.frame(
    session_id = "S01", camera_id = "TOP",
    track_id = rep(c("001", "B02", "C03"), each = 4L),
    time_s = rep(0:3, 3L),
    x = c(0,3,3,6, 0,0,0,0, 0,1,NA,4),
    y = c(0,4,4,8, 0,0,0,0, 0,0,NA,0),
    observed = c(rep(TRUE,8), TRUE,TRUE,FALSE,TRUE))
  src <- tempfile(fileext = ".csv")
  utils::write.csv(x, src, row.names = FALSE)
  z <- aqt_import_csv(src, units = "cm", coordinate_system = "tank")
  expect_equal(sort(unique(z$track_id)), c("001", "B02", "C03"))
  a <- aqt_kinematics(z, max_gap_s = 1.5)
  idx <- z$track_id == "001"
  expect_equal(a$step_distance[idx], c(NA, 5, 0, 5))
  expect_equal(a$speed[idx], c(NA, 5, 0, 5))
  expect_equal(a$acceleration[idx], c(NA, NA, -5, 5))
  p <- aqt_path_summary(z, max_gap_s = 1.5)
  expect_equal(p$path_length[p$track_id == "001"], 10)
  expect_equal(p$valid_duration_s[p$track_id == "001"], 3)
  expect_equal(p$mean_speed[p$track_id == "001"], 10/3)
  expect_equal(p$path_length[p$track_id == "B02"], 0)
  expect_equal(p$path_length[p$track_id == "C03"], 1)
  expect_equal(p$observed_fraction[p$track_id == "C03"], 0.75)
  script <- system.file("scripts", "aqt_qualify_existing_csv.R",
                        package = "aquaTrajectories")
  expect_true(file.exists(script))
  env <- new.env(parent = globalenv())
  sys.source(script, envir = env)
  out <- tempfile(pattern = "aqt_qualification_")
  audit <- env$aqt_qualify_existing_csv(src, out,
    units = "cm", coordinate_system = "tank", max_gap_s = 1.5)
  expect_identical(audit$independent_step_length_comparison, "PASS")
  expect_identical(audit$independent_path_summary_comparison, "PASS")
  expect_true(file.exists(file.path(out, "PATH_SUMMARY.csv")))
  expect_true(file.exists(file.path(out, "OBSERVED_2D_PATHS.pdf")))
  expect_gt(file.info(file.path(out, "OBSERVED_2D_PATHS.pdf"))$size, 1000)
  expect_error(env$aqt_qualify_existing_csv(src, out,
    units = "cm", coordinate_system = "tank"), "nonexistent")
})

test_that("3D checks include depth and refuse unqualified 3D rendering", {
  x <- data.frame(session_id = "S", camera_id = "CALIBRATED",
    track_id = "fish0007", time_s = c(0,2),
    x = c(0,3), y = c(0,4), z = c(0,12))
  src <- tempfile(fileext = ".csv")
  utils::write.csv(x, src, row.names = FALSE)
  script <- system.file("scripts", "aqt_qualify_existing_csv.R",
                        package = "aquaTrajectories")
  env <- new.env(parent = globalenv())
  sys.source(script, envir = env)
  out <- tempfile(pattern = "aqt_3d_qualification_")
  audit <- env$aqt_qualify_existing_csv(src, out,
    units = "cm", coordinate_system = "tank", max_gap_s = 3)
  expect_identical(audit$dimension, 3L)
  expect_false(audit$physical_xyz_calibration_certified)
  expect_false(audit$plot_2d_rendered)
  expect_false(file.exists(file.path(out, "OBSERVED_2D_PATHS.pdf")))
  k <- utils::read.csv(file.path(out, "KINEMATICS.csv"))
  expect_equal(k$step_distance, c(NA, 13))
  expect_equal(k$speed, c(NA, 6.5))
  expect_error(aqt_plot_path3d(aqt_tracks(transform(x, z = NA_real_))),
               "True 3D")
})

test_that("three-fish group spatial geometry matches independent triangle", {
  d <- data.frame(session_id = "S1", camera_id = "TOP", time_s = 0,
    track_id = c("A","B","C"), x = c(1,4,1), y = c(2,2,6))
  tracks <- aqt_tracks(d, units = "cm", coordinate_system = "tank")
  pair <- aqt_group_pairwise_distances(tracks)
  expect_equal(sort(pair$distance), c(3,4,5))
  g <- aqt_group_spatial_summary(tracks)
  expect_equal(g$centroid_x, 2)
  expect_equal(g$centroid_y, 10/3)
  expect_equal(g$radius_gyration, sqrt(50)/3)
  expect_equal(g$mean_pair_distance, 4)
  expect_equal(g$group_extent, 5)
})

test_that("invalid coordinates and duplicate times are rejected", {
  d <- data.frame(session_id = "S", camera_id = "TOP",
    track_id = "fish", time_s = c(0,1), x = c(0,NA), y = c(0,1))
  expect_error(aqt_tracks(d), "both")
  d$x[2] <- 1
  d$time_s[2] <- 0
  expect_error(aqt_tracks(d), "Duplicate")
  d$time_s[2] <- 1
  expect_error(aqt_plot_school3d(aqt_tracks(d), "S", "TOP", 0),
               "True calibrated 3D")
})


test_that("unobserved coordinates are not presented as visible fish paths", {
  d <- data.frame(session_id = "S", camera_id = "TOP", track_id = "001",
                  time_s = 0:2, x = c(1,999,3), y = c(1,999,3),
                  observed = c(TRUE,FALSE,TRUE))
  output <- tempfile(fileext = ".pdf")
  grDevices::pdf(output)
  tryCatch(expect_null(aqt_plot_paths(aqt_tracks(d))),
           finally = grDevices::dev.off())
  expect_gt(file.info(output)$size, 1000)
  d$observed <- FALSE
  expect_error(aqt_plot_paths(aqt_tracks(d)), "No observed")
})
