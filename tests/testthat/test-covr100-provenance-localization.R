# File-inventory hashes are not signatures; human identity corrections
# are source-scoped and must never overwrite original row identifiers.
.cov100_prov_tracks <- function() {
 d <- data.frame(session_id="S",camera_id="TOP",
   track_id=rep(c("A","B"),each=4),time_s=rep(0:3,2),
   x=rep(0:3,2),y=rep(c(0,1),each=4))
 aqt_tracks(d,units="cm",coordinate_system="tank")
}
.cov100_prov_correction <- function() {
 data.frame(session_id="S",camera_id="TOP",
   source_track_id="A",target_track_id="A.reviewed",
   start_s=1,end_s=2,reviewer="human",
   reason="independent visual annotation")
}
test_that("file inventory requires actual existing uniquely declared sources",{
 expect_error(aqt_provenance_new(character()),"nonempty file paths")
 expect_error(aqt_provenance_new(c(NA_character_)),"nonempty file paths")
 expect_error(aqt_provenance_new(list("x")),"nonempty file paths")
 expect_error(aqt_provenance_new(tempfile()),"existing files")
 tmp <- tempfile("cov100_files_")
 writeLines("source-not-truth",tmp)
 on.exit(unlink(tmp),add=TRUE)
 expect_error(aqt_provenance_new(tmp,metadata=list("x")),"named list")
 expect_error(aqt_provenance_new(tmp,metadata=1),"named list")
 expect_error(aqt_provenance_new(c(tmp,tmp)),"Duplicate file paths")
 manifest <- aqt_provenance_new(tmp,metadata=list(
      source="synthetic",original_rows_preserved=TRUE))
 expect_s3_class(manifest,"aqt_provenance")
 expect_identical(aqt_provenance_verify(manifest)$status,"match")
 writeLines("changed",tmp)
 changed <- aqt_provenance_verify(manifest)
 expect_identical(changed$status,"changed")
 unlink(tmp)
 expect_identical(aqt_provenance_verify(manifest)$status,"missing")
 expect_error(aqt_provenance_verify(list()),"Invalid provenance manifest")
})
test_that("human identity correction log enforces finite scopes and no overlap",{
 tr <- .cov100_prov_tracks(); corrections <- .cov100_prov_correction()
 expect_error(aqt_apply_identity_corrections(tr,list()),"corrections")
 bad <- corrections;bad$reviewer <- " "
 expect_error(aqt_apply_identity_corrections(tr,bad),"reviewer and reason")
 bad <- corrections;bad$source_track_id <- NA_character_
 expect_error(aqt_apply_identity_corrections(tr,bad),"reviewer and reason")
 bad <- corrections;bad$start_s <- Inf
 expect_error(aqt_apply_identity_corrections(tr,bad),"Invalid identity correction interval")
 bad <- corrections;bad$end_s <- 0
 expect_error(aqt_apply_identity_corrections(tr,bad),"Invalid identity correction interval")
 bad <- corrections;bad$target_track_id <- "B"
 expect_error(aqt_apply_identity_corrections(tr,bad),"Duplicate time within scoped track")
 bad <- corrections;bad$source_track_id <- "NotFound"
 expect_error(aqt_apply_identity_corrections(tr,bad),"does not match any source")
 bad <- rbind(corrections,corrections)
 expect_error(aqt_apply_identity_corrections(tr,bad),"Overlapping correction intervals")
 out <- aqt_apply_identity_corrections(tr,corrections)
 expect_equal(sum(out$identity_corrected),2L)
 expect_identical(unique(out$track_id[out$identity_corrected]),"A.reviewed")
 expect_identical(unique(out$original_track_id[out$identity_corrected]),"A")
 expect_equal(unique(out$correction_id[out$identity_corrected]),1L)
 expect_identical(as.data.frame(tr)$track_id,
          c(rep("A",4),rep("B",4)))
 expect_identical(attr(out,"aqt_correction_log")$reviewer,"human")
})
.cov100_pos_truth <- function() {
 data.frame(session_id="S",camera_id="C",frame_id=0:2,
    track_id="Reference",x=c(0,1,2),y=c(0,0,0),class_id="fish")
}
test_that("localization residuals retain unmatched zero rows and signed coordinates",{
 gt <- .cov100_pos_truth()
 pd <- gt;pd$track_id <- "Prediction"
 pd$x <- pd$x+c(.1,-.1,.2)
 pd$y <- pd$y+c(.2,0,-.1)
 expect_error(aqt_tracking_position_errors(gt,pd,max_distance=0),
              "max_distance")
 error <- aqt_tracking_position_errors(gt,pd,max_distance=1)
 expect_equal(nrow(error),3L)
 expect_equal(error$error_x,c(.1,-.1,.2),tolerance=1e-12)
 expect_equal(error$error_y,c(.2,0,-.1),tolerance=1e-12)
 s <- aqt_tracking_position_error_summary(error)
 expect_equal(s$n_matched,3L)
 expect_equal(s$bias_x,mean(c(.1,-.1,.2)),tolerance=1e-12)
 expect_equal(s$rmse_x,sqrt(mean(c(.1,-.1,.2)^2)),tolerance=1e-12)
 expect_false(is.na(s$sd_x))
 none <- aqt_tracking_position_errors(gt,pd,max_distance=.01)
 expect_equal(nrow(none),0L)
 expect_equal(length(none$error_x),0L)
 expect_equal(length(none$error_y),0L)
 expect_equal(nrow(aqt_tracking_position_error_summary(none)),0L)
 expect_error(aqt_tracking_position_error_summary(list()),
              "Expected matched position error table")
 bad <- error;bad$error_y[1] <- NA_real_
 expect_error(aqt_tracking_position_error_summary(bad),
              "Position errors must be finite")
 one <- aqt_tracking_position_error_summary(error[1,,drop=FALSE])
 expect_true(is.na(one$sd_x))
})
