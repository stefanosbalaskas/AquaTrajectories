# AquaTrajectories — existing-data qualification (no detector, tracker, or network).
# Source this script, then call aqt_qualify_existing_csv() with explicit paths.
aqt_qualify_existing_csv <- function(input_csv, output_dir,
                                     units = "px", coordinate_system = "image",
                                     max_gap_s = Inf) {
  if (!requireNamespace("aquaTrajectories", quietly = TRUE) ||
      !requireNamespace("digest", quietly = TRUE) ||
      !requireNamespace("jsonlite", quietly = TRUE))
    stop("Install aquaTrajectories and declared dependencies first", call. = FALSE)
  if (!is.character(input_csv) || length(input_csv) != 1L ||
      !file.exists(input_csv) || dir.exists(input_csv))
    stop("input_csv must point to one existing CSV file", call. = FALSE)
  if (!is.character(output_dir) || length(output_dir) != 1L ||
      is.na(output_dir) || !nzchar(output_dir) || file.exists(output_dir))
    stop("output_dir must be a new, nonexistent directory", call. = FALSE)
  if (!is.numeric(max_gap_s) || length(max_gap_s) != 1L ||
      is.na(max_gap_s) || max_gap_s <= 0)
    stop("max_gap_s must be a positive interval, or Inf", call. = FALSE)
  if (!dir.exists(dirname(output_dir)))
    stop("The parent of output_dir must already exist", call. = FALSE)
  input_csv <- normalizePath(input_csv, winslash = "/", mustWork = TRUE)
  tracks <- aquaTrajectories::aqt_import_csv(
    input_csv, units = units, coordinate_system = coordinate_system)
  aquaTrajectories::aqt_tracks_validate(tracks)
  d <- as.data.frame(tracks)
  if (nrow(d) == 0L) stop("Source CSV has zero observations", call. = FALSE)
  is3d <- identical(attr(tracks, "aqt_dimension"), 3L)
  axes <- c("x", "y", if (is3d) "z")
  kin <- aquaTrajectories::aqt_kinematics(tracks, max_gap_s = max_gap_s)
  paths <- aquaTrajectories::aqt_path_summary(tracks, max_gap_s = max_gap_s)
  groups <- aquaTrajectories::aqt_group_spatial_summary(tracks)

  # Separate base-R oracle; does not reuse computed package step values.
  oracle_step <- rep(NA_real_, nrow(d))
  oracle_dt <- rep(NA_real_, nrow(d))
  key <- paste(d$session_id, d$camera_id, d$track_id, sep = "\r")
  for (ix in split(seq_len(nrow(d)), key)) {
    if (length(ix) < 2L) next
    for (j in 2:length(ix)) {
      now <- ix[j]; previous <- ix[j - 1L]
      delta_t <- d$time_s[now] - d$time_s[previous]
      oracle_dt[now] <- delta_t
      if (delta_t <= 0 || delta_t > max_gap_s ||
          !d$observed[now] || !d$observed[previous]) next
      one <- as.numeric(as.matrix(d[now, axes, drop = FALSE]))
      zero <- as.numeric(as.matrix(d[previous, axes, drop = FALSE]))
      if (!all(is.finite(c(one, zero)))) next
      oracle_step[now] <- sqrt(sum((one - zero)^2))
    }
  }
  equal_na <- function(a, b, tol = 1e-10) {
    length(a) == length(b) && identical(is.na(a), is.na(b)) &&
      all(abs(a[!is.na(a)] - b[!is.na(b)]) <=
            tol * pmax(1, abs(a[!is.na(a)]), abs(b[!is.na(b)])))
  }
  if (!equal_na(oracle_dt, kin$dt_s) ||
      !equal_na(oracle_step, kin$step_distance))
    stop("Independent coordinate/time oracle disagrees with package kinematics",
         call. = FALSE)
  for (i in seq_len(nrow(paths))) {
    mask <- d$session_id == paths$session_id[i] &
      d$camera_id == paths$camera_id[i] &
      d$track_id == paths$track_id[i]
    expected_length <- sum(oracle_step[mask], na.rm = TRUE)
    expected_duration <- sum(oracle_dt[mask & !is.na(oracle_step)], na.rm = TRUE)
    if (!isTRUE(all.equal(paths$path_length[i], expected_length,
                          tolerance = 1e-10)) ||
        !isTRUE(all.equal(paths$valid_duration_s[i], expected_duration,
                          tolerance = 1e-10)))
      stop("Independent path-length/duration oracle disagrees with package",
           call. = FALSE)
  }
  if (!dir.create(output_dir, recursive = FALSE))
    stop("Cannot create clean output directory", call. = FALSE)
  write.csv(kin, file.path(output_dir, "KINEMATICS.csv"), row.names = FALSE)
  write.csv(paths, file.path(output_dir, "PATH_SUMMARY.csv"), row.names = FALSE)
  if (ncol(groups) > 0L) {
    write.csv(groups, file.path(output_dir, "GROUP_SPATIAL.csv"), row.names = FALSE)
  } else {
    writeLines("session_id,camera_id,time_s,n_visible,centroid_x,centroid_y,centroid_z,radius_gyration,mean_pair_distance,group_extent",
               file.path(output_dir, "GROUP_SPATIAL.csv"))
  }
  if (!is3d) {
    # Observed==FALSE may coexist with numeric coordinates. Mask such
    # coordinates in plots rather than silently presenting them as measured.
    display_tracks <- tracks
    display_tracks$x[!display_tracks$observed] <- NA_real_
    display_tracks$y[!display_tracks$observed] <- NA_real_
    if (!any(display_tracks$observed & is.finite(display_tracks$x) &
             is.finite(display_tracks$y)))
      stop("No observed 2D positions to plot", call. = FALSE)
    plot_file <- file.path(output_dir, "OBSERVED_2D_PATHS.pdf")
    grDevices::pdf(plot_file, width = 9, height = 6, onefile = TRUE)
    tryCatch(aquaTrajectories::aqt_plot_paths(display_tracks),
             finally = grDevices::dev.off())
  }
  report <- list(
    schema = "AQT_EXISTING_DATA_NUMERICAL_QUALIFICATION_V1",
    input_file_name = basename(input_csv),
    input_sha256 = digest::digest(file = input_csv, algo = "sha256"),
    package_version = as.character(utils::packageVersion("aquaTrajectories")),
    n_source_rows = nrow(d), n_scope_tracks = length(unique(key)),
    n_sessions = length(unique(d$session_id)),
    n_cameras = length(unique(paste(d$session_id, d$camera_id, sep = "\r"))),
    n_missing_or_unobserved_rows = sum(!d$observed |
      !stats::complete.cases(d[, axes, drop = FALSE])),
    dimension = if (is3d) 3L else 2L,
    units = units, coordinate_system = coordinate_system,
    max_gap_s = if (is.finite(max_gap_s)) max_gap_s else "Inf",
    independent_step_length_comparison = "PASS",
    independent_path_summary_comparison = "PASS",
    plot_2d_rendered = !is3d,
    input_timestamps_physically_verified = FALSE,
    biological_individual_identity_certified = FALSE,
    physical_xyz_calibration_certified = FALSE,
    native_plot_checked_for_rendering_only = TRUE,
    external_ground_truth_accuracy_established = FALSE,
    caveat = "Numerical checks compare package results with separate base-R formulas on the supplied coordinates; they do not certify the biological truth of those inputs."
  )
  jsonlite::write_json(report, file.path(output_dir, "QUALIFICATION_REPORT.json"),
                       pretty = TRUE, auto_unbox = TRUE, na = "null")
  print(report)
  invisible(report)
}
