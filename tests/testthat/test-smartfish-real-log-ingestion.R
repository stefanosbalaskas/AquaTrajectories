# Synthetic, public, non-fish-data fixtures for the archived smartFish
# 8-column header / 11-field observation export family.

.aqt_smartfish_mock <- function(plain_header=FALSE) {
  h <- if (plain_header)
    "Fish_ID,Width,Height,Depth(cm),Time,Top_Left,Bottom_Right,Center_Point"
  else
    "Fish_ID,Width(px),Height(px),Depth(cm),Time,Top_Left,Bottom_Right,Center_Point"
  lines <- c(h,
    "1,10,8,50,0,10,10,20,18,15,14",
    "1,10,8,50,0.5,13,10,23,18,18,14",
    "1,10,8,900,0.5,13,11,23,19,18,15",
    "1,10,8,900,1,14,11,24,19,19,15",
    "2,10,8,50,0,0,20,10,28,5,24",
    "2,10,8,50,0.5,4,20,14,28,9,24",
    "1,10,8,60,1.5,16,10,26,18,21,14")
  path <- tempfile(pattern="BEFORE_L_11025_",fileext="_tracking_log.txt")
  writeLines(lines,path,useBytes=TRUE)
  path
}

test_that("imports all source rows under eight-to-eleven smartFish schema",{
  path <- .aqt_smartfish_mock()
  on.exit(unlink(path),add=TRUE)
  x <- aqt_import_smartfish_log(path,session_id="session-A")
  expect_s3_class(x,"aqt_smartfish_log")
  expect_equal(nrow(x),7L)
  expect_equal(x$source_line,2:8)
  expect_identical(unique(x$camera_id),"unverified")
  expect_identical(unique(x$session_id),"session-A")
  expect_identical(unique(x$filename_phase),"Before")
  expect_identical(x$fish_id,c("1","1","1","1","2","2","1"))
  expect_equal(length(attr(x,"aqt_source_sha256")),1L)
  expect_equal(nchar(attr(x,"aqt_source_sha256")),64L)
  expect_identical(attr(x,"aqt_clock_scope"),
                   "per_track_relative_not_global_PTS")
  expect_false(attr(x,"aqt_animal_identity_certified"))
  expect_false(attr(x,"aqt_underwater_3d_certified"))
  expect_false(attr(x,"aqt_tank_replication_certified"))
  expect_equal(sum(x$qc_duplicate_id_time),2L)
  expect_equal(sum(x$qc_depth_at_or_above_cutoff),2L)
  expect_equal(sum(x$qc_box_on_boundary),1L)
  expect_equal(sum(x$qc_invalid_box_geometry),0L)
  expect_true(x$qc_nonincreasing_track_clock[3L])
  expect_true(all(x$depth_raw_cm[c(3,4)]==900))
})

test_that("accepts alternative header and rejects truncated or invalid files",{
  path <- .aqt_smartfish_mock(plain_header=TRUE)
  on.exit(unlink(path),add=TRUE)
  x <- aqt_import_smartfish_log(path)
  expect_equal(nrow(x),7L)
  expect_error(aqt_import_smartfish_log(path,
               image_size=c(1920,-1)),"image_size")
  expect_error(aqt_import_smartfish_log(path,
               depth_threshold_cm=-1),"depth_threshold")
  expect_error(aqt_import_smartfish_log(path,
               camera_id=" "),"nonblank")
  lines <- readLines(path)
  writeLines(lines[-length(lines)],path,useBytes=TRUE)
  expect_equal(nrow(aqt_import_smartfish_log(path)),6L)
  writeLines(c(lines,"1,2,3"),path,useBytes=TRUE)
  expect_error(aqt_import_smartfish_log(path),"exactly 11")
  writeLines(c("wrong,header,here",lines[-1L]),path,useBytes=TRUE)
  expect_error(aqt_import_smartfish_log(path),"8-field header")
})

test_that("QC audit counts tracks, source clock restarts and flagged rows",{
  path <- .aqt_smartfish_mock()
  on.exit(unlink(path),add=TRUE)
  x <- aqt_import_smartfish_log(path)
  z <- aqt_smartfish_log_audit(x)
  expect_equal(nrow(z),1L)
  expect_equal(z$n_observations,7L)
  expect_equal(z$n_track_ids,2L)
  expect_equal(z$n_track_clocks_start_at_zero,2L)
  expect_equal(z$n_duplicate_id_time_rows,2L)
  expect_equal(z$n_boundary_rows,1L)
  expect_equal(z$n_depth_at_or_above_cutoff,2L)
  expect_equal(z$max_raw_depth_cm,900)
  expect_true(attr(z,"not_global_camera_timestamps"))
  expect_false(attr(z,"estimated_depth_is_validated_water_depth"))
  expect_equal(nrow(aqt_smartfish_log_audit(list(x,x))),2L)
  expect_error(aqt_smartfish_log_audit(list()),"one or more")
})

test_that("image-plane adapter does not convert raw depth into fake 3D z",{
  path <- .aqt_smartfish_mock()
  on.exit(unlink(path),add=TRUE)
  x <- aqt_import_smartfish_log(path)
  t <- aqt_smartfish_tracks(x)
  expect_s3_class(t,"aqt_tracks")
  expect_equal(nrow(t),5L)
  expect_equal(attr(t,"aqt_observations_filtered"),2L)
  expect_true(all(is.na(t$z)))
  expect_equal(attr(t,"aqt_units"),"px")
  expect_equal(attr(t,"aqt_coordinate_system"),"image")
  expect_false(attr(t,"aqt_fish_identity_certified"))
  expect_false(attr(t,"aqt_3d_calibration_certified"))
  expect_false(attr(t,"aqt_physical_speed_certified"))
  expect_equal(unique(t$track_id),c("1","2"))
  expect_true(all(t$source_line %in% c(2L,5L,6L,7L,8L)))
  expect_error(aqt_smartfish_tracks(x,duplicate_policy="error"),
               "Duplicate source")
  first <- aqt_smartfish_tracks(x,duplicate_policy="first")
  expect_equal(nrow(first),6L)
  no_border <- aqt_smartfish_tracks(x,drop_boundary=TRUE)
  expect_equal(nrow(no_border),4L)
  no_cutoff <- aqt_smartfish_tracks(x,drop_depth_cutoff=TRUE)
  expect_equal(nrow(no_cutoff),4L)
})

test_that("motion uses only within-ID time steps and gap-based censoring",{
  path <- .aqt_smartfish_mock()
  on.exit(unlink(path),add=TRUE)
  tracks <- aqt_smartfish_tracks(aqt_import_smartfish_log(path))
  m <- aqt_smartfish_motion(tracks,max_gap_s=1)
  expect_equal(nrow(m),nrow(tracks))
  expect_equal(sum(m$valid_step),1L)
  step <- m[m$valid_step,,drop=FALSE]
  expect_equal(step$track_id,"2")
  expect_equal(step$dt_s,.5)
  expect_equal(step$dx_px,4)
  expect_equal(step$dy_px,0)
  expect_equal(step$speed_px_s,8)
  expect_equal(step$heading_rad,0)
  expect_true(all(is.na(m$speed_px_s[!m$valid_step])))
  expect_identical(attr(m,"speed_unit"),"px/s_uncalibrated")
  expect_false(attr(m,"body_heading_estimated"))
  m2 <- aqt_smartfish_motion(tracks,max_gap_s=2)
  expect_equal(sum(m2$valid_step),2L)
  expect_error(aqt_smartfish_motion(tracks,max_gap_s=0),"max_gap")
  expect_error(aqt_smartfish_motion(tracks,
               min_displacement_px=-1),"min_displacement")
  expect_error(aqt_smartfish_motion(data.frame()),"pixel tracks")
})

test_that("legacy replay reproduces historical filtering without certifying speed",{
  path <- .aqt_smartfish_mock()
  on.exit(unlink(path),add=TRUE)
  x <- aqt_import_smartfish_log(path)
  z <- aqt_smartfish_legacy_replay(
    x,nominal_cm_per_px=.1,speed_limits=c(.01,100))
  expect_equal(z$summary$n_legacy_filtered,3L)
  expect_equal(sort(z$observations$nominal_speed),
               sort(c(.6,.3,.8)),tolerance=1e-12)
  expect_false(attr(z,"physical_speed_cm_s_certified"))
  expect_false(attr(z,"stereo_depth_cm_is_vertical_z_certified"))
  expect_equal(attr(z,"reconstruction_type"),
               "historical_2d_fixed_scale_not_calibrated_3d")
  expect_error(aqt_smartfish_legacy_replay(x,
               speed_limits=c(10,1)),"speed_limits")
  expect_error(aqt_smartfish_legacy_replay(x,
               nominal_cm_per_px=0),"nominal_cm_per_px")
  expect_error(aqt_smartfish_legacy_replay(list()),"one or more")
})

test_that("smartFish headings can be supplied directly to rose plotting",{
  path <- .aqt_smartfish_mock()
  on.exit(unlink(path),add=TRUE)
  t <- aqt_smartfish_tracks(aqt_import_smartfish_log(path))
  m <- aqt_smartfish_motion(t,max_gap_s=2)
  x <- m[is.finite(m$heading_rad),c("condition","heading_rad")]
  expect_true(nrow(x)>0L)
  out <- tempfile(fileext=".pdf")
  grDevices::pdf(out)
  tryCatch({
    z <- aqt_plot_heading_rose(x,bins=8)
    expect_equal(sum(z$n_observations),nrow(x))
    expect_true(all(z$proportion>=0))
  },finally=grDevices::dev.off())
  unlink(out)
})
