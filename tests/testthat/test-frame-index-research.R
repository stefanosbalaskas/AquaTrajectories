testthat::test_that("frame-index analysis never fabricates timestamps or bridges gaps",{
  f <- data.frame(data_path=rep("reference",4),session_id="s",
                  camera_id="c",frame_id=0:3,width_px=100,
                  height_px=100,time_s=NA_real_)
  o <- data.frame(data_path="reference",session_id="s",camera_id="c",
      frame_id=c(0,1,3),track_id="001",x=c(10,13,40),y=c(10,14,50))
  a <- aqt_frame_index_analyze(f,o)
  testthat::expect_equal(a$summary$n_adjacent_frame_steps,1)
  testthat::expect_equal(a$summary$n_unbridged_within_track_gaps,1)
  testthat::expect_equal(a$observations$step_distance_px[2],5)
  testthat::expect_true(is.na(a$observations$step_distance_px[3]))
  testthat::expect_equal(a$summary$n_frames_without_observations,1)
  testthat::expect_false("speed" %in% names(a$observations))
  bad <- f;bad$time_s <- (0:3)/15
  testthat::expect_error(aqt_frame_index_analyze(bad,o),"time-aware")
  bad <- o;bad$frame_id[3] <- 1
  testthat::expect_error(aqt_frame_index_analyze(f,bad),"Duplicate")
  bad <- o;bad$x[1] <- 101
  testthat::expect_error(aqt_frame_index_analyze(f,bad),"outside")
})

testthat::test_that("path identities cannot mix reference and model",{
  f <- expand.grid(data_path=c("reference","model"),frame_id=0:1,
      KEEP.OUT.ATTRS=FALSE,stringsAsFactors=FALSE)
  f$session_id <- "s";f$camera_id <- "c"
  f$width_px <- 100;f$height_px <- 100;f$time_s <- NA_real_
  o <- data.frame(data_path=c("reference","reference","model","model"),
     session_id="s",camera_id="c",frame_id=c(0,1,0,1),track_id="01",
     x=c(0,3,60,60),y=c(0,4,50,52))
  a <- aqt_frame_index_analyze(f,o)
  testthat::expect_equal(a$summary$n_adjacent_frame_steps,c(1,1))
  testthat::expect_equal(sort(a$summary$observed_path_sum_px),c(2,5))
  testthat::expect_true(all(a$summary$n_local_track_labels==1))
  testthat::expect_true(all(a$group_geometry$n_visible==1L))
})


testthat::test_that("native frame-index publisher renders auditable figures and reports", {
  frames <- expand.grid(data_path=c("reference","model"),frame_id=0:2,
                        KEEP.OUT.ATTRS=FALSE,stringsAsFactors=FALSE)
  frames$session_id <- "synthetic_QA"
  frames$camera_id <- "single"
  frames$width_px <- 100
  frames$height_px <- 100
  frames$time_s <- NA_real_
  observed <- expand.grid(data_path=c("reference","model"),
                          track_id=c("01","02"),frame_id=0:2,
                          KEEP.OUT.ATTRS=FALSE,stringsAsFactors=FALSE)
  observed$session_id <- "synthetic_QA"
  observed$camera_id <- "single"
  observed$x <- ifelse(observed$track_id=="01",12,66)+
                as.double(observed$frame_id)
  observed$y <- ifelse(observed$track_id=="01",23,72)+
                as.double(observed$frame_id)*2
  study <- aqt_frame_index_analyze(frames,observed)
  dest <- tempfile("m07-native-publication-")
  on.exit(unlink(dest,recursive=TRUE,force=TRUE),add=TRUE)
  testthat::expect_invisible(aqt_frame_index_publish(study,dest))
  testthat::expect_true(file.exists(file.path(dest,"REPORT.html")))
  testthat::expect_true(file.exists(file.path(dest,"REPORT.md")))
  testthat::expect_true(file.exists(file.path(dest,
                                             "M07_FRAME_INDEX_ANALYSIS.rds")))
  for(ext in c("svg","pdf","png")){
    files <- list.files(file.path(dest,"figures"),
                        pattern=paste0("\\.",ext,"$"),full.names=TRUE)
    testthat::expect_equal(length(files),4L)
    testthat::expect_true(all(file.info(files)$size>100L))
  }
  catalog <- utils::read.csv(file.path(dest,"FIGURE_CATALOG.csv"))
  testthat::expect_equal(nrow(catalog),4L)
  testthat::expect_true(all(catalog$status=="complete"))
  manifest <- jsonlite::fromJSON(file.path(dest,"M07_SCIENCE_MANIFEST.json"),
                                  simplifyVector=FALSE)
  testthat::expect_identical(manifest$schema,
                              "AQT_M07_FRAME_INDEX_SCIENCE_PUBLICATION_V1")
  testthat::expect_identical(manifest$n_figures_complete,4L)
  for(n in names(manifest$output_sha256)){
    actual <- unname(digest::digest(file.path(dest,n),
                                    file=TRUE,algo="sha256"))
    testthat::expect_identical(actual,manifest$output_sha256[[n]])
  }
  report_text <- paste(readLines(file.path(dest,"REPORT.html"),
                                 warn=FALSE),collapse="\n")
  testthat::expect_match(report_text,"<svg",fixed=TRUE)
  testthat::expect_match(report_text,"No measured timestamps",fixed=TRUE)
})
