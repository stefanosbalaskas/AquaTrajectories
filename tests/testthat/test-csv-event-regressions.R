# Synthetic regression cases only. No private research observations.

test_that("canonical 2D CSV round-trip preserves absent z as numeric", {
  d <- data.frame(
    session_id=c("01","01","01"),
    camera_id=c("002","002","002"),
    track_id=c("0007","0007","0008"),
    time_s=c(0,0.25,0),
    x=c(2.25,3.5,11.5),
    y=c(10,12,30),
    observed=TRUE,
    stringsAsFactors=FALSE)
  original <- aqt_tracks(d,units="px",coordinate_system="image")
  expect_true(is.numeric(original$z))
  expect_true(all(is.na(original$z)))
  path <- tempfile(fileext=".csv")
  on.exit(unlink(path),add=TRUE)
  aqt_export_csv(original,path)
  recovered <- aqt_import_csv(path,units="px",coordinate_system="image")
  expect_s3_class(recovered,"aqt_tracks")
  expect_true(aqt_tracks_validate(recovered))
  expect_identical(recovered$session_id,original$session_id)
  expect_identical(recovered$camera_id,original$camera_id)
  expect_identical(recovered$track_id,original$track_id)
  expect_identical(recovered$time_s,original$time_s)
  expect_equal(recovered[,c("x","y")],original[,c("x","y")])
  expect_identical(recovered$observed,original$observed)
  expect_type(recovered$z,"double")
  expect_true(all(is.na(recovered$z)))
  expect_identical(attr(recovered,"aqt_dimension"),2L)
  expect_identical(attr(recovered,"aqt_units"),"px")
  expect_identical(attr(recovered,"aqt_coordinate_system"),"image")
})

test_that("canonical 3D CSV round-trip is unchanged", {
  d <- data.frame(session_id="0042",camera_id="02",
                  track_id="0000005",time_s=c(0,.25,1),
                  x=c(1,2,3),y=c(3,4,5),z=c(.1,.2,.3),
                  observed=c(TRUE,FALSE,TRUE),stringsAsFactors=FALSE)
  original <- aqt_tracks(d,units="cm",coordinate_system="tank")
  path <- tempfile(fileext=".csv")
  on.exit(unlink(path),add=TRUE)
  aqt_export_csv(original,path)
  recovered <- aqt_import_csv(path,units="cm",
                               coordinate_system="tank")
  expect_identical(recovered$track_id,original$track_id)
  expect_identical(recovered$session_id,original$session_id)
  expect_identical(recovered$camera_id,original$camera_id)
  expect_equal(recovered$z,original$z)
  expect_equal(recovered$x,original$x)
  expect_identical(recovered$observed,original$observed)
  expect_identical(attr(recovered,"aqt_dimension"),3L)
})

test_that("all-NA XY remain numeric without inventing a detection",{
  d <- data.frame(session_id="S",camera_id="C",track_id="A",
      time_s=c(0,1),x=c(NA_real_,NA_real_),
      y=c(NA_real_,NA_real_),observed=FALSE)
  original <- aqt_tracks(d)
  path <- tempfile(fileext=".csv")
  on.exit(unlink(path),add=TRUE)
  aqt_export_csv(original,path)
  recovered <- aqt_import_csv(path)
  expect_type(recovered$x,"double")
  expect_type(recovered$y,"double")
  expect_type(recovered$z,"double")
  expect_true(all(!recovered$observed))
  expect_equal(nrow(recovered),2L)
})

test_that("CSV importer does not conceal malformed nonmissing positions", {
  path <- tempfile(fileext=".csv")
  on.exit(unlink(path),add=TRUE)
  writeLines(c("session_id,camera_id,track_id,time_s,x,y,z",
               "S,C,001,0,invalid,1,"),path)
  expect_error(aqt_import_csv(path),"x must be numeric")
})

test_that("aligning an event with no matching session returns zero rows", {
  d <- aqt_tracks(data.frame(
    session_id="S1",camera_id="C",track_id="A",
    time_s=0:2,x=0:2,y=0:2))
  e <- data.frame(session_id="S2",event_id="feed",
                  start_s=0,end_s=1,stringsAsFactors=FALSE)
  out <- aqt_align_events(d,e)
  expect_s3_class(out,"data.frame")
  expect_equal(nrow(out),0L)
  expect_true(all(c("session_id","time_s","event_id",
                    "event_start_s","event_end_s",
                    "relative_time_s","phase") %in% names(out)))
  expect_type(out$relative_time_s,"double")
  expect_type(out$phase,"character")
})

test_that("event windows may exclude all samples without an error", {
  d <- aqt_tracks(data.frame(
    session_id="S1",camera_id="C",track_id="A",
    time_s=c(0,1),x=c(0,1),y=c(2,3)))
  e <- data.frame(session_id="S1",event_id="late",
                  start_s=100,end_s=101)
  out <- aqt_align_events(d,e,window_s=c(-2,2))
  expect_equal(nrow(out),0L)
  expect_true("phase" %in% names(out))
})

test_that("one absent event does not discard another valid alignment",{
  d <- aqt_tracks(data.frame(
    session_id="S1",camera_id="C",track_id="A",
    time_s=c(0,1,2),x=c(0,1,2),y=c(0,0,0)))
  e <- data.frame(
    session_id=c("NO_RECORDING","S1"),
    event_id=c("missing","feeding"),
    start_s=c(0,1),end_s=c(0,1))
  out <- aqt_align_events(d,e,window_s=c(-1,1))
  expect_equal(nrow(out),3L)
  expect_true(all(out$event_id=="feeding"))
  expect_equal(out$relative_time_s,c(-1,0,1))
  expect_equal(out$phase,c("before","during","after"))
  expect_equal(out$event_start_s,c(1,1,1))
})

test_that("event alignment keeps overlapping events separate",{
  d <- data.frame(session_id="S",time_s=0:2,signal=c(8,9,10))
  e <- data.frame(session_id=c("S","S"),event_id=c("A","B"),
                  start_s=c(0,1),end_s=c(0,1))
  out <- aqt_align_events(d,e,window_s=c(0,1))
  expect_equal(nrow(out),4L)
  expect_equal(as.integer(table(out$event_id)),c(2L,2L))
  expect_equal(out$relative_time_s,c(0,1,0,1))
  expect_equal(out$signal,c(8,9,9,10))
})
