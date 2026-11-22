# Contract-edge tests for scientific frame-index analysis and publication.
# Source frames are synthetic and have explicitly UNKNOWN timestamps.

.cov100_frame_source <- function() {
  f <- data.frame(data_path="reference",session_id="S",
      camera_id="C",frame_id=0:3,width_px=100,
      height_px=80,time_s=NA_real_,stringsAsFactors=FALSE)
  o <- data.frame(data_path="reference",session_id="S",
      camera_id="C",frame_id=c(0,1,3),track_id="F1",
      x=c(10,13,30),y=c(12,16,40),stringsAsFactors=FALSE)
  list(f=f,o=o)
}

test_that("frame-index import explicitly rejects malformed acquisition evidence", {
  z <- .cov100_frame_source()
  f <- z$f; o <- z$o
  expect_error(aqt_frame_index_analyze(data.frame(),o),"Nonempty")
  expect_error(aqt_frame_index_analyze(f,data.frame()),"Nonempty")
  expect_error(aqt_frame_index_analyze(f[,setdiff(names(f),"width_px")],o),
               "Missing required")
  expect_error(aqt_frame_index_analyze(f,o,occupancy_bins=1.5),"must be integers")
  expect_error(aqt_frame_index_analyze(f,o,occupancy_bins=1),"safe bounds")
  expect_error(aqt_frame_index_analyze(f,o,max_fish_per_frame=201),"safe bounds")
  bad <- f;bad$session_id[1] <- ""
  expect_error(aqt_frame_index_analyze(bad,o),"Missing frame/observation")
  bad <- o;bad$camera_id[1] <- NA_character_
  expect_error(aqt_frame_index_analyze(f,bad),"Missing frame/observation")
  bad <- o;bad$track_id[1] <- ""
  expect_error(aqt_frame_index_analyze(f,bad),"Track ID")
  bad <- f;bad$width_px <- as.character(bad$width_px)
  expect_error(aqt_frame_index_analyze(bad,o),"integer-valued")
  bad <- f;bad$frame_id[1] <- -1
  expect_error(aqt_frame_index_analyze(bad,o),"Invalid frame ID")
  bad <- f;bad$height_px[1] <- 0
  expect_error(aqt_frame_index_analyze(bad,o),"Invalid frame ID")
  bad <- o;bad$frame_id <- as.character(bad$frame_id)
  expect_error(aqt_frame_index_analyze(f,bad),"Invalid observation")
  bad <- o;bad$frame_id[1] <- 1.5
  expect_error(aqt_frame_index_analyze(f,bad),"Invalid observation")
  bad <- o;bad$x[1] <- NA_real_
  expect_error(aqt_frame_index_analyze(f,bad),"finite numeric")
  bad <- o;bad$y <- as.character(bad$y)
  expect_error(aqt_frame_index_analyze(f,bad),"finite numeric")
  bad <- f;bad$frame_id[2] <- 0
  expect_error(aqt_frame_index_analyze(bad,o),"Duplicate acquired")
  bad <- f[-1,,drop=FALSE]
  expect_error(aqt_frame_index_analyze(bad,o),"every recorded local frame")
  bad <- f;bad$width_px[2] <- 101
  expect_error(aqt_frame_index_analyze(bad,o),"Variable image geometry")
  bad <- o;bad$frame_id[3] <- 7
  expect_error(aqt_frame_index_analyze(f,bad),"missing original frame")
  bad <- o;bad$x[1] <- 150
  expect_error(aqt_frame_index_analyze(f,bad),"outside source image")
  bad <- o;bad$detection_confidence <- c("0.9","-0.1","0.9")
  expect_error(aqt_frame_index_analyze(f,bad),"detection confidence")
  bad <- o;bad$detection_confidence <- c("1",NA,"not-a-number")
  expect_error(aqt_frame_index_analyze(f,bad),"detection confidence")
  good <- o;good$detection_confidence <- c("1",NA,"0.2")
  a <- aqt_frame_index_analyze(f,good)
  expect_equal(a$summary$n_adjacent_frame_steps,1)
  expect_true(all(is.na(a$frames$time_s)))
})

test_that("source paths and singleton tracks do not manufacture geometry or time", {
  f <- expand.grid(data_path=c("reference","extra"),session_id=c("S1","S2"),
      frame_id=0:2,KEEP.OUT.ATTRS=FALSE,stringsAsFactors=FALSE)
  f$camera_id <- "C"
  f$width_px <- 100
  f$height_px <- 100
  f$time_s <- NA_real_
  o <- data.frame(data_path=c("reference","extra"),
      session_id=c("S1","S2"),camera_id="C",frame_id=c(0,1),
      track_id=c("01","02"),x=c(10,30),y=c(20,40),
      stringsAsFactors=FALSE)
  a <- aqt_frame_index_analyze(f,o)
  expect_equal(sum(a$summary$n_observations),2L)
  expect_true(all(!a$group_geometry$geometry_eligible))
  expect_true(all(is.na(a$group_geometry$radius_of_gyration_px)))
  expect_equal(sum(a$summary$n_frames_without_observations),10L)
  expect_true(all(is.na(a$observations$step_distance_px)))
  expect_error(aqt_frame_index_publish(list(),tempfile()),"Expected")
  expect_error(aqt_frame_index_publish(a,tempdir()),"new and parent")
  parent <- tempfile("aqt_cov100_frames_")
  dir.create(parent)
  on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
  target <- file.path(parent,"research")
  expect_invisible(aqt_frame_index_publish(a,target))
  expect_true(file.exists(file.path(target,"REPORT.html")))
  expect_true(file.exists(file.path(target,"M07_SCIENCE_MANIFEST.json")))
  figs <- list.files(file.path(target,"figures"),pattern="\\.svg$")
  expect_equal(length(figs),8L)
  for(nm in figs) {
    xml <- paste(readLines(file.path(target,"figures",nm),
                           warn=FALSE),collapse="\n")
    expect_true(grepl("<svg",xml,fixed=TRUE))
    expect_true(grepl("</svg>",xml,fixed=TRUE))
  }
})
