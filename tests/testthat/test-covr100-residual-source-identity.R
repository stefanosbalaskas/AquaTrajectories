# Focused residual coverage: true 3D sparse observations, namespace-collision
# rejection and explicitly absent observations. Entirely synthetic fixtures.
test_that("YOLO import refuses rows without an identity column", {
  path <- tempfile("cov100_missing_yolo_id_", fileext=".csv")
  on.exit(unlink(path), add=TRUE)
  utils::write.csv(data.frame(x_px=2, y_px=3, time_s=0),
                   path, row.names=FALSE)
  expect_error(
    aqt_import_yolo(path, session_id="S", camera_id="C"),
    "Expected track_id/fish_id"
  )
})

test_that("sparse FPCA reads measured third-axis trajectories without depth invention", {
  xyz <- aqt_simulate_tracks(n_fish=5L, n_frames=6L,
                             dimension=3L, seed=802L)
  expect_identical(attr(xyz, "aqt_dimension"), 3L)
  out <- aqt_sparse_fpca_input(xyz, coordinate="z",
                               time_axis="absolute")
  expect_identical(out$axis, "z")
  expect_identical(out$dimension, 3L)
  expect_equal(length(out$Ly), 5L)
  expect_true(all(vapply(out$Ly, function(z) all(is.finite(z)), logical(1L))))
  expect_equal(out$Lt[[1L]], xyz$time_s[xyz$track_id=="fish1"])
  expect_true(all(out$scope$n_observed==6L))
})

test_that("DTW rejects ambiguous human-readable labels for different scoped paths", {
  first <- data.frame(session_id="A/B", camera_id="C", track_id="D",
                      time_s=0:3, x=c(0,1,2,3), y=c(2,2,2,2))
  second <- data.frame(session_id="A", camera_id="B/C", track_id="D",
                       time_s=0:3, x=c(1,2,3,4), y=c(3,3,3,3))
  tracks <- aqt_tracks(rbind(first,second), units="cm",
                        coordinate_system="tank")
  expect_equal(length(unique(paste(tracks$session_id, tracks$camera_id,
                                   tracks$track_id, sep="\r"))), 2L)
  expect_error(aqt_trajectory_dtw_matrix(tracks),
               "Ambiguous display labels")
})

test_that("3D storyboard cannot reinterpret unobserved physical XYZ as evidence", {
  xyz <- aqt_simulate_tracks(n_fish=1L, n_frames=6L,
                             dimension=3L, seed=111L)
  # Positions are deliberately still present; the observation flag controls
  # scientific eligibility and must not be silently overridden.
  xyz$observed[] <- FALSE
  expect_invisible(aqt_tracks_validate(xyz))
  expect_error(aqt_plot_trajectory_storyboard3d(xyz),
               "No genuine observed XYZ positions")
})

test_that("YOLO track_id takes precedence over alternate fish_id without losing leading zeros", {
  path <- tempfile("cov100_track_id_precedence_",fileext=".csv")
  on.exit(unlink(path),add=TRUE)
  raw <- data.frame(track_id=c("0007","0007"),
                    fish_id=c("wrong_A","wrong_B"),
                    x_px=c(11,12),y_px=c(21,22),time_s=c(0,.1),
                    stringsAsFactors=FALSE)
  utils::write.csv(raw,path,row.names=FALSE,quote=TRUE)
  result <- aqt_import_yolo(path,session_id="S",camera_id="TOP")
  expect_identical(as.character(result$track_id),c("0007","0007"))
  expect_identical(as.character(result$session_id),c("S","S"))
  expect_identical(as.character(result$camera_id),c("TOP","TOP"))
  expect_equal(result$x,c(11,12))
  expect_equal(result$y,c(21,22))
  expect_equal(result$time_s,c(0,.1))
  expect_false(any(result$track_id %in% raw$fish_id))
})
