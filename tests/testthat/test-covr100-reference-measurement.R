# Reference-measurement validation retains original M07 source rows and an
# explicit, evaluator-supplied source-row match table. No animal ID ground truth.
.cov100_m08_source <- function() {
 frames <- expand.grid(data_path=c("reference","model"),frame_id=0:1,
    KEEP.OUT.ATTRS=FALSE,stringsAsFactors=FALSE)
 frames$session_id <- "S";frames$camera_id <- "TOP"
 frames$width_px <- 100;frames$height_px <- 100
 frames$time_s <- NA_real_
 ref <- data.frame(data_path="reference",session_id="S",camera_id="TOP",
   frame_id=0:1,track_id="A",x=c(10,11),y=c(10,10))
 mod <- data.frame(data_path="model",session_id="S",camera_id="TOP",
   frame_id=0:1,track_id="X",x=c(10,11),y=c(10,10))
 obs <- rbind(ref,mod)
 obs$bbox_left <- obs$x-5;obs$bbox_top <- obs$y-5
 obs$bbox_width <- 10;obs$bbox_height <- 10
 matched <- data.frame(session_id="S",camera_id="TOP",frame_id=0:1,
   reference_track_id="A",model_track_id="X",
   reference_source_row=1:2,model_source_row=3:4,
   reference_x_px=obs$x[1:2],reference_y_px=obs$y[1:2],
   model_x_px=obs$x[3:4],model_y_px=obs$y[3:4],
   iou=1,position_error_px=0)
 list(frames=frames,obs=obs,matched=matched)
}
test_that("M08 refuses invalid reference source tables and unmeasured clocks",{
 z <- .cov100_m08_source()
 call <- function(f=z$frames,o=z$obs,m=z$matched,threshold=.5)
    aqt_reference_measurement_validate(f,o,m,iou_threshold=threshold)
 expect_error(call(f=data.frame()),"Expected nonempty")
 expect_error(call(o=data.frame()),"Expected nonempty")
 expect_error(call(m=list()),"Expected nonempty")
 expect_error(call(threshold=0),"IoU threshold")
 expect_error(call(threshold=1.1),"IoU threshold")
 expect_error(call(threshold=Inf),"IoU threshold")
 bad <- z$obs;bad$bbox_width <- NULL
 expect_error(call(o=bad),"Incomplete original observation")
 bad <- z$frames;bad$height_px <- NULL
 expect_error(call(f=bad),"Incomplete original observation")
 bad <- z$matched;bad$iou <- NULL
 expect_error(call(m=bad),"Incomplete original observation")
 bad <- z$obs;bad$data_path <- "reference"
 expect_error(call(o=bad),"Source separation")
 bad <- z$frames;bad$time_s[1] <- 0
 expect_error(call(f=bad),"Source separation and unknown time")
 bad <- z$obs;bad$x[1] <- Inf
 expect_error(call(o=bad),"Invalid source observation geometry")
 bad <- z$obs;bad$bbox_width[2] <- -1
 expect_error(call(o=bad),"Invalid source observation geometry")
 bad <- z$frames;bad$frame_id[2] <- bad$frame_id[1]
 expect_error(call(f=bad),"Missing or duplicate original acquisition")
 bad <- z$obs;bad$track_id[2] <- bad$track_id[1]
 bad$frame_id[2] <- bad$frame_id[1]
 expect_error(call(o=bad),"Missing or duplicate original acquisition")
 bad <- z$obs;bad$frame_id[1] <- 100
 expect_error(call(o=bad),"Missing or duplicate original acquisition")
})
test_that("M08 rejects source-matched table corruption without inflating agreement",{
 z <- .cov100_m08_source()
 call <- function(m=z$matched) aqt_reference_measurement_validate(
       z$frames,z$obs,m,iou_threshold=.5)
 bad <- z$matched;bad$reference_source_row[1] <- 0
 expect_error(call(m=bad),"Invalid or duplicated source")
 bad <- z$matched;bad$model_source_row[1] <- 999
 expect_error(call(m=bad),"Invalid or duplicated source")
 bad <- z$matched;bad$model_source_row[2] <- bad$model_source_row[1]
 expect_error(call(m=bad),"Invalid or duplicated source")
 bad <- z$matched;bad$reference_track_id[1] <- "Wrong"
 expect_error(call(m=bad),"camera scope")
 bad <- z$matched;bad$model_track_id[1] <- "Wrong"
 expect_error(call(m=bad),"camera scope")
 bad <- z$matched;bad$frame_id[1] <- 1
 expect_error(call(m=bad),"camera scope")
 bad <- z$matched;bad$iou[1] <- .1
 expect_error(call(m=bad),"Reported IoU")
 bad <- z$matched;bad$model_x_px[1] <- 99
 expect_error(call(m=bad),"Reported IoU")
 bad <- z$matched;bad$position_error_px[1] <- 99
 expect_error(call(m=bad),"Reported IoU")
 good <- call()
 expect_equal(good$recomputed_iou,c(1,1))
 expect_equal(good$summary$n_matched,2)
 expect_equal(good$summary$n_paired_same_id_steps,1)
 expect_equal(good$adjacent_reference_steps$reference_step_px,1)
 expect_equal(good$adjacent_reference_steps$vector_error_px,0)
 expect_false(good$independent_biological_id_certified)
})
test_that("M08 unmatched/reference-only cases retain undefined scientific denominators",{
 z <- .cov100_m08_source()
 empty <- z$matched[FALSE,,drop=FALSE]
 study <- aqt_reference_measurement_validate(z$frames,z$obs,empty)
 expect_equal(study$summary$n_matched,0)
 expect_equal(study$summary$n_reference_adjacent_steps,1)
 expect_equal(study$summary$n_reference_steps_missing_match_endpoint,1)
 expect_true(is.na(study$summary$median_position_error_px))
 expect_equal(nrow(study$group_geometry),2)
 expect_true(all(is.na(study$group_geometry$matched_reference_rg_px)))
 z$frames <- z$frames[z$frames$frame_id==0,,drop=FALSE]
 z$obs <- z$obs[z$obs$frame_id==0,,drop=FALSE]
 one <- aqt_reference_measurement_validate(z$frames,z$obs,empty)
 expect_equal(nrow(one$adjacent_reference_steps),0)
 expect_true(is.na(one$summary$paired_step_fraction))
 expect_error(aqt_reference_measurement_publish(list(),tempfile()),"Expected intact")
 folder <- tempfile("m08_empty_")
 dir.create(folder)
 on.exit(unlink(folder,recursive=TRUE,force=TRUE),add=TRUE)
 expect_error(aqt_reference_measurement_publish(one,folder),
              "Require new output location")
 out <- file.path(folder,"report")
 expect_invisible(aqt_reference_measurement_publish(study,out))
 expect_true(file.exists(file.path(out,"M08_SCIENTIFIC_ANALYSIS.rds")))
 expect_identical(readRDS(file.path(out,"M08_SCIENTIFIC_ANALYSIS.rds"))$source_data,
                  study$source_data)
})
