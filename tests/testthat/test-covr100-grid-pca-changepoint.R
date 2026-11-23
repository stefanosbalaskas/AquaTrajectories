# Dense finite-grid PCA, not sparse FPCA or biological population inference.
.cov100_grid_tracks <- function(nfish=4L,identical_paths=FALSE,three=FALSE) {
 d <- do.call(rbind,lapply(seq_len(nfish),function(i) {
   tt <- 0:5
   fish <- if(identical_paths)1 else i
   out <- data.frame(session_id="S",camera_id="C",
      track_id=paste0("F",i),time_s=tt,
      x=fish*tt,y=fish^2*tt^2,observed=TRUE)
   if(three)out$z <- rep(2,6)
   out
 }))
 aqt_tracks(d,units="cm",coordinate_system="tank")
}
test_that("finite-grid trajectory PCA refuses unsupported design and interpolation",{
 d <- .cov100_grid_tracks()
 expect_error(aqt_trajectory_grid_pca(d,n_grid=1),"between 5 and 1000")
 expect_error(aqt_trajectory_grid_pca(d,n_grid=1001),"between 5 and 1000")
 expect_error(aqt_trajectory_grid_pca(d,n_grid=5.5),"between 5 and 1000")
 expect_error(aqt_trajectory_grid_pca(d,n_components=0),"positive integer")
 expect_error(aqt_trajectory_grid_pca(d,n_components=1.2),"positive integer")
 expect_error(aqt_trajectory_grid_pca(d,n_components=4),"independent PCA rank")
 one <- .cov100_grid_tracks(nfish=2)
 expect_error(aqt_trajectory_grid_pca(one),"3..500 paths")
 none <- aqt_tracks(as.data.frame(d)[0,,drop=FALSE],
                   units="cm",coordinate_system="tank")
 expect_error(aqt_trajectory_grid_pca(none),"No trajectories supplied")
 expect_error(aqt_trajectory_grid_pca(d,max_gap_s=.5),"gaps exceed")
 same <- .cov100_grid_tracks(identical_paths=TRUE)
 expect_error(aqt_trajectory_grid_pca(same),"identical")
 fit <- aqt_trajectory_grid_pca(d,n_grid=7,n_components=2)
 expect_s3_class(fit,"aqt_grid_pca")
 expect_equal(fit$n_paths,4L)
 expect_equal(sum(fit$explained_variance)+
          sum((fit$mode_sd[-(1:2)])^2),sum(fit$explained_variance))
 expect_true(all(fit$explained_variance>0))
 expect_true(all(diff(fit$time_relative)>0))
 expect_false(grepl("sparse",fit$implementation,fixed=TRUE) &&
              !grepl("not sparse",fit$implementation,fixed=TRUE))
 expect_error(aqt_plot_grid_pca(list()),"Expected an aqt_grid_pca")
 expect_error(aqt_plot_grid_pca(fit,component=0),"Unknown PCA component")
 expect_error(aqt_plot_grid_pca(fit,component=3),"Unknown PCA component")
 expect_error(aqt_plot_grid_pca(fit,component=1.5),"Unknown PCA component")
 grDevices::pdf(tempfile(fileext=".pdf"))
 on.exit(grDevices::dev.off(),add=TRUE)
 expect_invisible(aqt_plot_grid_pca(fit,component=1))
 expect_invisible(aqt_plot_grid_pca(fit,component=2))
 three <- aqt_trajectory_grid_pca(.cov100_grid_tracks(three=TRUE),
                          n_grid=7,n_components=2)
 expect_equal(three$dimension,3L)
 expect_invisible(aqt_plot_grid_pca(three))
})
.cov100_changepoint_source <- function() {
 data.frame(session_id="S",camera_id="C",track_id="Fish",
   time_s=0:11,speed=c(rep(1,6),rep(8,6)),observed=TRUE)
}
test_that("segmentation keeps no interpolation and penalized known-truth break",{
 d <- .cov100_changepoint_source()
 expect_error(aqt_state_changepoint(list(),penalty=1),"Expected one complete")
 bad <- d;bad$speed <- as.character(bad$speed)
 expect_error(aqt_state_changepoint(bad,penalty=1),"numeric behaviour")
 bad <- d;bad$time_s[1] <- Inf
 expect_error(aqt_state_changepoint(bad,penalty=1),"Missing/nonfinite")
 bad <- d;bad$observed <- 1
 expect_error(aqt_state_changepoint(bad,penalty=1),"Non-observed or invalid")
 expect_error(aqt_state_changepoint(d,penalty=-1),"finite nonnegative")
 expect_error(aqt_state_changepoint(d,penalty=NA_real_),"finite nonnegative")
 expect_error(aqt_state_changepoint(d,penalty=1,min_segment=2),"integer >=3")
 expect_error(aqt_state_changepoint(d,penalty=1,min_segment=3.5),"integer >=3")
 expect_error(aqt_state_changepoint(d,penalty=1,max_gap_s=0),"positive")
 expect_error(aqt_state_changepoint(d,penalty=1,max_gap_s=.9),"gaps exceed")
 bad <- d;bad$track_id[1] <- "Other"
 expect_error(aqt_state_changepoint(bad,penalty=1),"one scoped fish")
 short <- d[1:5,,drop=FALSE]
 expect_error(aqt_state_changepoint(short,penalty=1,min_segment=3),
              "Require two potential segments")
 duplicate <- d;duplicate$time_s[2] <- duplicate$time_s[1]
 expect_error(aqt_state_changepoint(duplicate,penalty=1),"Duplicate timestamps")
 fit <- aqt_state_changepoint(d,penalty=1,min_segment=3)
 expect_equal(fit$n_segments,2L)
 expect_equal(fit$break_after_index,6L)
 expect_equal(fit$change_time_s,5.5,tolerance=1e-12)
 expect_equal(fit$segments$mean_value,c(1,8),tolerance=1e-12)
 expect_false(fit$empirical_significance_test)
 conservative <- aqt_state_changepoint(d,penalty=1e6,min_segment=3)
 expect_equal(conservative$n_segments,1L)
 ev <- data.frame(session_id="S",event_id=c("near","after"),
             start_s=c(5,30),end_s=c(5,30))
 expect_error(aqt_changepoint_event_delay(list(),ev),"Expected aqt_changepoints")
 expect_error(aqt_changepoint_event_delay(fit,ev,max_delay_s=-1),
              "finite and nonnegative")
 off <- transform(ev,session_id="other")
 expect_error(aqt_changepoint_event_delay(fit,off),"No events in")
 latency <- aqt_changepoint_event_delay(fit,ev,max_delay_s=1)
 expect_equal(latency$delay_s[1],.5,tolerance=1e-12)
 expect_true(is.na(latency$delay_s[2]))
 expect_identical(latency$has_change,c(TRUE,FALSE))
 expect_error(aqt_plot_changepoints(list()),"Expected aqt_changepoints")
 grDevices::pdf(tempfile(fileext=".pdf"))
 on.exit(grDevices::dev.off(),add=TRUE)
 expect_invisible(aqt_plot_changepoints(fit))
 expect_invisible(aqt_plot_changepoints(conservative))
})

test_that("finite source positions with nonfinite interpolator results cannot reach PCA",{
 tr <- .cov100_grid_tracks()
 testthat::with_mocked_bindings({
   expect_error(aqt_trajectory_grid_pca(tr,n_grid=7,n_components=2),
                "cannot be interpolated onto the full grid")
 },.aqt_grid_approx=function(x,y,xout,...) list(y=rep(Inf,length(xout))),
   .package="aquaTrajectories")
})
test_that("change-point dynamic program refuses numerical overflow before segmentation",{
 d <- .cov100_changepoint_source()
 d$speed <- rep(c(1e154,-1e154),6L)
 expect_error(aqt_state_changepoint(d,penalty=1,min_segment=3L),
              "No permissible segmentation under declared minimum duration")
})
