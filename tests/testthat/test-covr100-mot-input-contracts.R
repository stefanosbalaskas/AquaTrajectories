# Original video PTS is external, not inferred from arbitrary frame IDs.
.cov100_mot_parts <- function() {
 frames <- aqt_frame_manifest(data.frame(
   session_id="S",camera_id="TOP",frame_id=c(0,1,3),
   time_s=c(0,.1,.35),width_px=100,height_px=80))
 mot <- data.frame(frame=c(1,4),id=c("0007","0007"),
   left=c(10,12),top=c(20,20),width=c(10,10),height=c(10,10),
   confidence=c(.9,.95),unused_x=-1,unused_y=-1,unused_z=-1)
 list(frames=frames,mot=mot)
}
test_that("MOT frame manifests reject blanks, invalid dimensions and impossible PTS",{
 z <- .cov100_mot_parts()
 d <- as.data.frame(z$frames)
 expect_error(aqt_frame_manifest(data.frame()),"nonempty camera")
 bad <- d;bad$session_id[1] <- ""
 expect_error(aqt_frame_manifest(bad),"identifiers must be complete")
 bad <- d;bad$width_px <- as.character(bad$width_px)
 expect_error(aqt_frame_manifest(bad),"finite numeric")
 bad <- d;bad$time_s[2] <- Inf
 expect_error(aqt_frame_manifest(bad),"finite numeric")
 bad <- d;bad$height_px[1] <- 0
 expect_error(aqt_frame_manifest(bad),"dimensions positive")
 bad <- d;bad$frame_id[1] <- -1
 expect_error(aqt_frame_manifest(bad),"nonnegative integers")
 bad <- d;bad$time_s[1] <- -.1
 expect_error(aqt_frame_manifest(bad),"PTS nonnegative")
 bad <- d;bad$camera_id[1] <- "NEW"
 expect_s3_class(aqt_frame_manifest(bad),"aqt_frame_manifest")
 expect_false(attr(z$frames,"aqt_hardware_synchronization_certified"))
})
test_that("MOT adapter rejects missing source frames, invalid labels and swapped class keys",{
 z <- .cov100_mot_parts()
 call <- function(m=z$mot,...)aqt_import_mot(m,z$frames,"S","TOP",...)
 expect_error(call(m=list()),"seven positional columns")
 expect_error(call(m=data.frame(x=1)),"seven positional columns")
 expect_error(aqt_import_mot(z$mot,z$frames,"","TOP"),
              "One complete session_id")
 expect_error(call(frame_origin=-1),"nonnegative integer")
 expect_error(call(frame_origin=1.5),"nonnegative integer")
 bad <- z$mot;bad$frame <- as.character(bad$frame)
 expect_error(call(m=bad),"finite numeric")
 bad <- z$mot;bad$left[1] <- Inf
 expect_error(call(m=bad),"finite numeric")
 bad <- z$mot;bad$id[1] <- "fish"
 expect_error(call(m=bad),"numeric strings")
 bad <- z$mot;bad$frame[1] <- 0
 expect_error(call(m=bad),"numeric strings")
 bad <- z$mot;bad$top[1] <- -1
 expect_error(call(m=bad),"nonnegative top-left")
 bad <- z$mot;bad$confidence[2] <- 2
 expect_error(call(m=bad),"prediction confidence must be within")
 bad <- z$mot;bad$left[1] <- 98
 expect_error(call(m=bad),"outside recorded image")
 bad <- z$mot;bad$frame[2] <- 3
 expect_error(call(m=bad),"absent from supplied video PTS")
 expect_error(call(class_ids="fish"),"class_ids must")
 expect_error(call(class_ids=c("fish","shrimp")),"may not change")
 path <- tempfile(fileext=".txt")
 file.create(path)
 on.exit(unlink(path),add=TRUE)
 empty <- call(m=path)
 expect_s3_class(empty,"aqt_mot_tracks")
 expect_equal(nrow(empty),0)
 expect_equal(nrow(aqt_mot_support_audit(empty,z$frames)),0)
 result <- call()
 expect_equal(result$frame_id,c(0,3))
 expect_equal(result$time_s,c(0,.35))
 expect_equal(result$track_id,c("0007","0007"))
 expect_identical(attr(result,"aqt_timing_source"),"external_video_pts")
 expect_false(attr(result,"aqt_fish_identity_certified"))
})
test_that("MOT support audit refuses source-frame mismatch and preserves dropped-frame accounting",{
 z <- .cov100_mot_parts()
 tracks <- aqt_import_mot(z$mot,z$frames,"S","TOP")
 s <- aqt_mot_support_audit(tracks,z$frames)
 expect_equal(s$n_observations,2)
 expect_equal(s$n_missing_acquired_between,1)
 expect_equal(s$n_absent_frame_numbers_between,1)
 expect_equal(s$max_inter_observation_s,.35)
 bad <- tracks;bad$frame_id[2] <- 100
 expect_error(aqt_mot_support_audit(bad,z$frames),"do not match")
 bad <- tracks;bad$time_s[2] <- .3
 expect_error(aqt_mot_support_audit(bad,z$frames),"do not match")
 expect_error(aqt_mot_support_audit(as.data.frame(tracks),z$frames),
              "Expected aqt_mot_tracks")
 expect_error(aqt_mot_support_audit(tracks,as.data.frame(z$frames)),
              "Expected aqt_frame_manifest")
})
