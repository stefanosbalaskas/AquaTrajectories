# Synthetic-only metamorphic and source-lineage tests. These do not certify fish
# identity, animal welfare, physical metrology or real sensor accuracy.

test_that("QC sensitivity preserves every 2D/3D row and blocks source frame skips", {
  x <- data.frame(session_id="S",camera_id="C",track_id="0007",
    frame_id=c(0,1,3,4),time_s=c(0,1,2,3),
    x=c(0,1,3,4),y=c(0,0,0,0),z=c(1,1,1,1),
    observed=TRUE,source_row=c(3L,7L,8L,9L))
  tr <- aqt_tracks(x,units="cm",coordinate_system="tank")
  original <- serialize(tr,NULL)
  result <- aqt_qc_sensitivity(tr,gap_limits_s=c(1.01,2.01),
                                speed_limits=c(1.1,4))
  expect_s3_class(result,"aqt_qc_sensitivity")
  expect_equal(nrow(result$policies),4L)
  expect_equal(nrow(result$ledger),16L)
  expect_identical(serialize(tr,NULL),original)
  expect_true(all(result$summary$n_eligible_steps==2L))
  expect_true(all(result$summary$path_length==2))
  expect_true(all(result$summary$n_source_rows==4L))
  expect_true(all(result$ledger$source_row %in% c("3","7","8","9")))
  expect_true(all(result$ledger$reason[result$ledger$input_row==3L]==
                  "nonadjacent_source_frame"))
  expect_equal(result$units,"cm")
  expect_equal(result$dimension,3L)
  expect_false(result$biological_accuracy_certified)
})

test_that("QC sensitivity on arbitrary 2D time data is monotone in threshold", {
  x <- data.frame(session_id="S",camera_id="C",track_id="A",
    time_s=c(0,1,2,4),x=c(0,1,4,5),y=0,
    observed=TRUE)
  tr <- aqt_tracks(x)
  z <- aqt_qc_sensitivity(tr,gap_limits_s=c(1.1,2.1),
                          speed_limits=c(2,5))
  expect_equal(z$summary$n_eligible_steps,c(1,2,2,3))
  expect_equal(z$summary$path_length,c(1,2,4,5))
  expect_equal(z$summary$valid_duration_s,c(1,3,2,4))
  expect_true(all(z$ledger$step_eligible %in% c(TRUE,FALSE)))
  expect_error(aqt_qc_sensitivity(tr,c(-1,2)),"positive")
  expect_error(aqt_qc_sensitivity(tr,rep(1,2)),"unique")
  expect_error(aqt_qc_sensitivity(tr,rep(1:4,each=5),rep(1:4,each=4)),"unique")
})

test_that("kinematics satisfy translation rotation scaling and missing-gap invariants", {
  set.seed(331)
  for (i in seq_len(40L)) {
    n <- sample(7:25,1L)
    dx <- rnorm(n); dy <- rnorm(n)
    x <- data.frame(session_id="S",camera_id="C",track_id="A",
      time_s=seq_len(n),x=cumsum(dx),y=cumsum(dy),observed=TRUE)
    base <- aqt_tracks(x,units="cm",coordinate_system="tank")
    ang <- runif(1L,-pi,pi)
    shift <- c(runif(1L,-30,30),runif(1L,-30,30))
    f <- x
    f$x <- x$x*cos(ang)-x$y*sin(ang)+shift[1]
    f$y <- x$x*sin(ang)+x$y*cos(ang)+shift[2]
    rot <- aqt_tracks(f,units="cm",coordinate_system="tank")
    expect_equal(aqt_path_summary(base)$path_length,
                 aqt_path_summary(rot)$path_length,tolerance=1e-8)
    expect_equal(aqt_kinematics(base)$speed,
                 aqt_kinematics(rot)$speed,tolerance=1e-8)
    c <- runif(1L,.3,4)
    f$x <- f$x*c; f$y <- f$y*c
    scaled <- aqt_tracks(f,units="cm",coordinate_system="tank")
    expect_equal(aqt_path_summary(scaled)$path_length,
                 c*aqt_path_summary(base)$path_length,tolerance=1e-8)
    k <- x
    k$observed[4L] <- FALSE
    k$x[4L] <- NA_real_;k$y[4L] <- NA_real_
    missing <- aqt_tracks(k,units="cm",coordinate_system="tank")
    z <- aqt_kinematics(missing)
    expect_true(is.na(z$step_distance[4L]))
    expect_true(is.na(z$step_distance[5L]))
  }
})

test_that("school geometry is unchanged under fish ID relabelling", {
  d <- data.frame(session_id="S",camera_id="C",
    track_id=rep(c("A","B","C"),each=3),
    time_s=rep(0:2,3),x=rep(c(0,3,0),each=3),
    y=rep(c(0,0,4),each=3),observed=TRUE)
  a <- aqt_tracks(d,units="cm",coordinate_system="tank")
  d$track_id <- c(C="Q",B="R",A="S")[d$track_id]
  b <- aqt_tracks(d,units="cm",coordinate_system="tank")
  p <- aqt_group_metrics(a)
  q <- aqt_group_metrics(b)
  expect_equal(p$mean_nearest_neighbor,q$mean_nearest_neighbor,
               tolerance=1e-10)
  expect_equal(p$centroid_x,q$centroid_x,tolerance=1e-10)
  expect_equal(p$centroid_y,q$centroid_y,tolerance=1e-10)
})

test_that("multi-format figure export is hash-linked, new-only and cleans failure", {
  dest <- tempfile("aqt-figure-core2-")
  on.exit(unlink(dest,recursive=TRUE),add=TRUE)
  source <- tempfile("aqt-figure-input-")
  on.exit(unlink(source),add=TRUE)
  writeLines("recorded external source reference",source)
  aqt_figure_export(function() graphics::plot(0:5,0:5),dest,
                    formats="pdf",source_file=source,caption="Synthetic example")
  expect_true(file.exists(file.path(dest,"figure.pdf")))
  m <- jsonlite::fromJSON(file.path(dest,"FIGURE_MANIFEST.json"),
                           simplifyVector=FALSE)
  expect_identical(m$source_file_sha256,
    unname(digest::digest(source,file=TRUE,algo="sha256")))
  expect_identical(m$output_sha256[["figure.pdf"]],
    unname(digest::digest(file.path(dest,"figure.pdf"),
                          file=TRUE,algo="sha256")))
  expect_false(m$source_measurement_certified)
  expect_error(aqt_figure_export(function() graphics::plot(1),dest),"new path")
  faildest <- tempfile("aqt-figure-error-")
  on.exit(unlink(faildest,recursive=TRUE),add=TRUE)
  expect_error(aqt_figure_export(function() stop("intentional"),
                                 faildest,formats="pdf"),"intentional")
  expect_false(file.exists(faildest))
  if(capabilities("png")) {
    pngdest <- tempfile("aqt-figure-png-")
    on.exit(unlink(pngdest,recursive=TRUE),add=TRUE)
    aqt_figure_export(function() graphics::plot(1:4),pngdest,
                      formats=c("pdf","png"),dpi=120L)
    expect_true(file.info(file.path(pngdest,"figure.png"))$size>100)
  }
})
