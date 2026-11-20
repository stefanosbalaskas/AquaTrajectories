testthat::test_that("M08 source-linked measurement validates IoU and ID continuity",{
  frames <- expand.grid(data_path=c("reference","model"),frame_id=0:2,
                        KEEP.OUT.ATTRS=FALSE,stringsAsFactors=FALSE)
  frames$session_id <- "test-seq"
  frames$camera_id <- "camera_1"
  frames$time_s <- NA_real_
  frames$width_px <- 100
  frames$height_px <- 100
  a <- data.frame(data_path="reference",session_id="test-seq",
    camera_id="camera_1",frame_id=c(0,1,2,0,1),track_id=c("A","A","A","B","B"),
    x=c(10,12,14,40,41),y=10)
  b <- data.frame(data_path="model",session_id="test-seq",
    camera_id="camera_1",frame_id=c(0,1,2,0),track_id=c("X","X","Y","Z"),
    x=c(11,13,15,40.5),y=10)
  obs <- rbind(a,b)
  obs$bbox_left <- obs$x-5
  obs$bbox_top <- obs$y-5
  obs$bbox_width <- 10
  obs$bbox_height <- 10
  r <- c(1,2,3,4)
  p <- c(6,7,8,9)
  iou <- vapply(seq_along(r),function(j) {
    aa <- obs[r[j],,drop=FALSE]
    bb <- obs[p[j],,drop=FALSE]
    x1 <- max(aa$bbox_left,bb$bbox_left)
    x2 <- min(aa$bbox_left+aa$bbox_width,bb$bbox_left+bb$bbox_width)
    overlap <- max(0,x2-x1)*10
    overlap/(200-overlap)
  },numeric(1))
  mm <- data.frame(session_id="test-seq",camera_id="camera_1",
    frame_id=c(0,1,2,0),reference_track_id=c("A","A","A","B"),
    model_track_id=c("X","X","Y","Z"),reference_source_row=r,
    model_source_row=p,reference_x_px=obs$x[r],reference_y_px=obs$y[r],
    model_x_px=obs$x[p],model_y_px=obs$y[p],iou=iou,
    position_error_px=abs(obs$x[r]-obs$x[p]))
  result <- aqt_reference_measurement_validate(frames,obs,mm,iou_threshold=.5)
  testthat::expect_equal(nrow(result$adjacent_reference_steps),3L)
  testthat::expect_equal(sum(result$adjacent_reference_steps$status=="matched_same_id"),1L)
  testthat::expect_equal(sum(result$adjacent_reference_steps$status=="model_id_discontinuity"),1L)
  testthat::expect_equal(sum(result$adjacent_reference_steps$status=="unmatched_endpoint"),1L)
  testthat::expect_equal(result$summary$n_matched,4L)
  testthat::expect_equal(result$summary$n_reference_adjacent_steps,3L)
  testthat::expect_equal(result$summary$n_paired_same_id_steps,1L)
  testthat::expect_equal(result$summary$paired_step_MAE_px,0)
  testthat::expect_true(!result$physical_3D_certified)
  testthat::expect_true(!result$independent_biological_id_certified)
  altered <- mm
  altered$iou[1] <- .99
  testthat::expect_error(aqt_reference_measurement_validate(frames,obs,altered),
                         "Reported IoU")
  altered <- mm
  altered$model_source_row[2] <- altered$model_source_row[1]
  testthat::expect_error(aqt_reference_measurement_validate(frames,obs,altered),
                         "duplicated")
  altered <- mm
  altered$frame_id[1] <- 2
  testthat::expect_error(aqt_reference_measurement_validate(frames,obs,altered),
                         "camera scope")
  frames$time_s[1] <- 0
  testthat::expect_error(aqt_reference_measurement_validate(frames,obs,mm),
                         "unknown time")
  dest <- tempfile("m08-reference-")
  on.exit(unlink(dest,recursive=TRUE,force=TRUE),add=TRUE)
  testthat::expect_invisible(aqt_reference_measurement_publish(result,dest))
  testthat::expect_true(file.exists(file.path(dest,"M08_SCIENTIFIC_ANALYSIS.rds")))
  testthat::expect_true(file.exists(file.path(dest,"M08_R_OUTPUT_MANIFEST.json")))
  audit <- jsonlite::fromJSON(file.path(dest,"M08_R_OUTPUT_MANIFEST.json"),
                               simplifyVector=FALSE)
  for(n in names(audit$output_sha256)) {
    testthat::expect_identical(unname(digest::digest(file.path(dest,n),
      algo="sha256",file=TRUE)),audit$output_sha256[[n]])
  }
})
