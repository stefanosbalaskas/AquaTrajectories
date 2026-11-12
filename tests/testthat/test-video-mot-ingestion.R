.aqt_mot_fixture <- function() {
  f <- data.frame(
    session_id="S1",camera_id="TOP",
    frame_id=c(0,1,3,4),
    time_s=c(0,.041,.152,.195),
    width_px=100,height_px=80)
  m <- aqt_frame_manifest(f)
  # MOTChallenge fields: 1-based frame, numeric track, xleft, ytop,
  # box width, box height, predicted confidence, plus optional extras.
  raw <- data.frame(
    frame=c(1,4,5),id=c(1,2,1),
    left=c(10,50,12),top=c(20,20,20),
    width=c(10,10,10),height=c(8,8,8),
    confidence=c(.96,.85,.93),
    unused_world_x=-1,unused_world_y=-1,unused_world_z=-1)
  list(frames=m,mot=raw)
}

test_that("explicit frame PTS remain intact with dropped/variable frames", {
  f <- .aqt_mot_fixture()
  expect_s3_class(f$frames,"aqt_frame_manifest")
  expect_equal(f$frames$frame_id,c(0,1,3,4))
  expect_equal(f$frames$time_s,c(0,.041,.152,.195))
  expect_true(attr(f$frames,"aqt_clock_source")==
              "externally_supplied_per_frame_pts")
  expect_false(attr(f$frames,"aqt_hardware_synchronization_certified"))
  j <- aqt_frame_manifest(f$frames[4:1,,drop=FALSE])
  expect_equal(j$frame_id,c(0,1,3,4))
  expect_equal(j$time_s,c(0,.041,.152,.195))
  expect_error(aqt_frame_manifest(transform(f$frames,
      time_s=c(0,.04,.04,.2))),"strictly increase")
  expect_error(aqt_frame_manifest(transform(f$frames,
      width_px=c(100,100,99,100))),"remain constant")
  expect_error(aqt_frame_manifest(transform(f$frames,
      frame_id=c(0,1,1,4))),"Duplicate frame")
  expect_error(aqt_frame_manifest(transform(f$frames,
      frame_id=c(0,1,2.5,4))),"nonnegative integers")
  expect_error(aqt_frame_manifest(transform(f$frames,
      time_s=c(0,.04,-.1,.2))),"nonnegative")
})

test_that("MOT export uses externally acquired timestamps and correct XYWH centres", {
  f <- .aqt_mot_fixture()
  tracks <- aqt_import_mot(f$mot,f$frames,"S1","TOP",
    class_ids=c("seabass","seabream","seabass"))
  expect_s3_class(tracks,"aqt_mot_tracks")
  expect_s3_class(tracks,"aqt_tracks")
  expect_equal(nrow(tracks),3)
  expect_equal(unique(tracks$track_id),c("1","2"))
  one <- tracks[tracks$track_id=="1",,drop=FALSE]
  expect_equal(one$frame_id,c(0,4))
  expect_equal(one$time_s,c(0,.195))
  expect_equal(one$x,c(15,17))
  expect_equal(one$y,c(24,24))
  expect_equal(one$confidence,c(.96,.93))
  expect_true(all(one$class_id=="seabass"))
  expect_true(all(tracks$observed))
  expect_true(all(is.na(tracks$z)))
  expect_equal(attr(tracks,"aqt_units"),"px")
  expect_identical(attr(tracks,"aqt_timing_source"),"external_video_pts")
  expect_false(attr(tracks,"aqt_tracking_model_validated"))
  expect_false(attr(tracks,"aqt_fish_identity_certified"))
  expect_equal(attr(tracks,"aqt_video_metadata")$n_manifest_frames,4)
})

test_that("gap audit distinguishes acquired video gaps from dropped frame IDs", {
  f <- .aqt_mot_fixture()
  t <- aqt_import_mot(f$mot,f$frames,"S1","TOP")
  q <- aqt_mot_support_audit(t,f$frames)
  expect_equal(nrow(q),2)
  one <- q[q$track_id=="1",,drop=FALSE]
  expect_equal(one$n_observations,2)
  expect_equal(one$n_acquired_between_endpoints,4)
  expect_equal(one$n_missing_acquired_between,2)
  expect_equal(one$n_absent_frame_numbers_between,1)
  expect_equal(one$max_inter_observation_s,.195)
  expect_equal(one$first_pts_s,0)
  expect_equal(one$last_pts_s,.195)
  other <- q[q$track_id=="2",,drop=FALSE]
  expect_equal(other$n_observations,1)
  expect_equal(other$n_missing_acquired_between,0)
  expect_true(is.na(other$max_inter_observation_s))
  tampered <- t
  tampered$time_s[tampered$track_id=="2"] <- .160
  expect_error(aqt_mot_support_audit(tampered,f$frames),
               "do not match")
})

test_that("MOT adapter reads standard headerless CSV tracker exports", {
  f <- .aqt_mot_fixture()
  tmp <- tempfile(fileext=".txt")
  on.exit(unlink(tmp),add=TRUE)
  utils::write.table(f$mot,tmp,sep=",",row.names=FALSE,
                     col.names=FALSE,quote=FALSE)
  from_file <- aqt_import_mot(tmp,f$frames,"S1","TOP")
  direct <- aqt_import_mot(f$mot,f$frames,"S1","TOP")
  expect_equal(as.data.frame(from_file),as.data.frame(direct))
  expect_equal(from_file$time_s,direct$time_s)
})

test_that("MOT import fails closed on missing frames, IDs and invalid boxes", {
  f <- .aqt_mot_fixture()
  call <- function(x=f$mot,frames=f$frames,...)
    aqt_import_mot(x,frames,"S1","TOP",...)
  expect_error(call(transform(f$mot,frame=c(1,4,6))),
               "absent from supplied")
  expect_error(call(transform(f$mot,id=c(1,-1,1))),
               "nonnegative numeric strings")
  expect_error(call(transform(f$mot,width=c(0,10,10))),
               "positive size")
  expect_error(call(transform(f$mot,left=c(96,50,12))),
               "outside recorded image")
  expect_error(call(transform(f$mot,confidence=c(.96,-1,.93))),
               "confidence")
  expect_error(call(transform(f$mot,frame=c(1,1,5),
                              id=c(1,1,1))),
               "Duplicate time")
  expect_error(call(class_ids=c("fish","fish")),
               "class_ids")
  expect_error(call(class_ids=c("seabass","bream","bream")),
               "may not change")
  expect_error(call(frame_origin=.5),"frame_origin")
  expect_error(aqt_import_mot(f$mot,f$frames,"S2","TOP"),
               "No manifest")
  expect_error(aqt_import_mot(f$mot,as.data.frame(f$frames),
                              "S1","TOP"),"aqt_frame_manifest")
})

test_that("camera-local IDs never collapse across separately recorded views", {
  f <- .aqt_mot_fixture()
  manifest <- aqt_frame_manifest(rbind(
    as.data.frame(f$frames),
    transform(as.data.frame(f$frames),camera_id="SIDE",
              time_s=time_s+.005)))
  top <- aqt_import_mot(f$mot,manifest,"S1","TOP")
  side <- aqt_import_mot(f$mot,manifest,"S1","SIDE")
  both <- rbind(as.data.frame(top),as.data.frame(side))
  expect_equal(length(unique(paste(both$camera_id,both$track_id))),4)
  expect_equal(nrow(both),6)
  ref <- both[,c("session_id","camera_id","frame_id",
                "track_id","x","y")]
  comparison <- aqt_tracking_metrics(ref,ref,max_distance=0)
  expect_equal(nrow(comparison),2)
  expect_true(all(comparison$IDF1==1))
})
