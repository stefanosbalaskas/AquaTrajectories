# Frame-index study is descriptive image-space analysis when true video
# PTS is absent. Plot rendering cannot substitute frame numbers for seconds.
.cov100_frame_index_study <- function(nfish=2L) {
 frames <- data.frame(data_path="reference",session_id="S",
   camera_id="TOP",frame_id=0:3,width_px=100,height_px=80,
   time_s=as.numeric(rep(NA,4)))
 obs <- do.call(rbind,lapply(seq_len(nfish),function(i)
    data.frame(data_path="reference",session_id="S",
     camera_id="TOP",frame_id=0:3,track_id=paste0("F",i),
     x=5+0:3+i,y=rep(i*7,4))))
 aqt_frame_index_analyze(frames,obs,occupancy_bins=4)
}
test_that("frame-index analysis refuses invented acquisition times and duplicate identities",{
 f <- data.frame(data_path="reference",session_id="S",camera_id="C",
   frame_id=0:2,width_px=50,height_px=60,time_s=as.numeric(rep(NA,3)))
 o <- data.frame(data_path="reference",session_id="S",camera_id="C",
   frame_id=0:2,track_id="F",x=1:3,y=3:1)
 fun <- function(fr=f,obs=o,...)
     aqt_frame_index_analyze(fr,obs,...)
 expect_error(fun(fr=f[FALSE,,drop=FALSE]),"Nonempty frame")
 expect_error(fun(obs=o[FALSE,,drop=FALSE]),"Nonempty frame")
 bad <- f;bad$time_s[1] <- 0
 expect_error(fun(fr=bad),"unknown timestamps only")
 bad <- f;bad$frame_id[2] <- bad$frame_id[1]
 expect_error(fun(fr=bad),"Duplicate acquired frame")
 bad <- f;bad$frame_id[2] <- 10
 expect_error(fun(fr=bad),"every recorded local frame")
 bad <- o;bad$frame_id[2] <- bad$frame_id[1]
 expect_error(fun(obs=bad),"Duplicate camera-local identity")
 bad <- f;bad$width_px[2] <- 51
 expect_error(fun(fr=bad),"Variable image geometry")
 bad <- o;bad$x[1] <- 200
 expect_error(fun(obs=bad),"outside source image")
 bad <- o;bad$frame_id[1] <- 100
 expect_error(fun(obs=bad),"missing original frame")
 expect_error(fun(occupancy_bins=1),"outside safe bounds")
 expect_error(fun(occupancy_bins=51),"outside safe bounds")
 expect_error(fun(max_fish_per_frame=1),"outside safe bounds")
 expect_error(fun(max_fish_per_frame=201),"outside safe bounds")
 expect_error(fun(occupancy_bins=2.5),"must be integers")
 expect_true(is.list(fun()))
})
test_that("publishing frame-index figures emits only source-based graphics",{
 if(!requireNamespace("svglite",quietly=TRUE)||
    !requireNamespace("ragg",quietly=TRUE))
   testthat::skip("Optional headless publication devices unavailable")
 study <- .cov100_frame_index_study()
 parent <- tempfile("cov100_fi_parent_");dir.create(parent)
 on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
 dest <- file.path(parent,"publication")
 expect_error(aqt_frame_index_publish(list(),dest),
              "Expected aqt_frame_index_study")
 expect_error(aqt_frame_index_publish(study,parent),
              "Output directory must be new")
 expect_error(aqt_frame_index_publish(study,file.path(parent,"absent","export")),
              "Output directory must be new")
 raw <- serialize(study$observations,NULL)
 expect_invisible(aqt_frame_index_publish(study,dest))
 expect_identical(serialize(study$observations,NULL),raw)
 expect_true(file.exists(file.path(dest,"FIGURE_CATALOG.csv")))
 expect_true(file.exists(file.path(dest,"M07_FRAME_INDEX_ANALYSIS.rds")))
 cat <- utils::read.csv(file.path(dest,"FIGURE_CATALOG.csv"))
 expect_equal(nrow(cat),4L)
 expect_true(all(cat$status=="complete"))
 expect_true(all(vapply(as.character(cat$svg),function(f)
              file.exists(file.path(dest,f)),logical(1))))
 expect_true(all(vapply(as.character(cat$png),function(f)
              file.info(file.path(dest,f))$size>100,logical(1))))
 expect_identical(readRDS(file.path(dest,"M07_FRAME_INDEX_ANALYSIS.rds"))$metadata$elapsed_time_status,"unknown")
})
test_that("frame-index plot refuses silently broken source adjacency and cleans partial output",{
 if(!requireNamespace("svglite",quietly=TRUE)||
    !requireNamespace("ragg",quietly=TRUE))
    testthat::skip("Optional headless publication devices unavailable")
 study <- .cov100_frame_index_study(nfish=1)
 bad <- study
 idx <- which(is.finite(bad$observations$step_distance_px))[1L]
 bad$observations$previous_frame_id[idx] <- 999
 parent <- tempfile("cov100_broken_frame_");dir.create(parent)
 on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
 dest <- file.path(parent,"must_not_publish")
 expect_error(aqt_frame_index_publish(bad,dest),
              "Adjacent-frame source segment cannot be reconstructed")
 expect_false(dir.exists(dest))
})
