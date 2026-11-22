# Computational guards must fire BEFORE allocating huge DTW and RQA
# matrices. Geometrically finite but numerically unresolvable distances
# are rejected instead of falsely reported as measured similarities.
.cov100_long_path <- function(n,track="A",offset=0) {
 d <- data.frame(session_id="S",camera_id="C",track_id=track,
   time_s=seq_len(n)-1L,x=(seq_len(n)-1L)*.01+offset,
   y=rep(0,n),observed=TRUE)
 aqt_tracks(d,units="cm",coordinate_system="tank")
}
test_that("long source trajectories trigger DTW and recurrence pre-allocation caps",{
 a <- .cov100_long_path(1415L,"A")
 b <- .cov100_long_path(1415L,"B")
 expect_error(aqt_trajectory_dtw(a,b,window=0),
              "DTW cost matrix cap exceeded")
 too_long <- .cov100_long_path(2001L)
 expect_error(aqt_trajectory_recurrence(too_long,radius=1),
              "Recurrence matrix cap exceeded")
})
test_that("finite but overflowing Euclidean distances are explicitly unestimable",{
 a <- .cov100_long_path(3L,"A")
 b <- .cov100_long_path(3L,"B")
 da <- as.data.frame(a);db <- as.data.frame(b)
 da$x[] <- 1e308
 db$x[] <- -1e308
 a <- aqt_tracks(da,units="cm",coordinate_system="tank")
 b <- aqt_tracks(db,units="cm",coordinate_system="tank")
 expect_error(aqt_trajectory_dtw(a,b,window=0),
              "No valid path under specified DTW window")
})
