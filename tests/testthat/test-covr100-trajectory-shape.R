# Independent geometric trajectory invariants: alignment and recurrence are
# descriptive and do not establish biological identity or physical time warping.
.cov100_paths <- function() {
 d <- data.frame(session_id="S",camera_id="C",
   track_id=rep(c("A","B"),each=4),time_s=rep(0:3,2),
   x=c(0:3,1:4),y=c(0,0,0,0,0,0,0,0),observed=TRUE)
 aqt_tracks(d,units="cm",coordinate_system="tank")
}
.cov100_path <- function(fish="A") {
 d <- as.data.frame(.cov100_paths())
 aqt_tracks(d[d$track_id==fish,,drop=FALSE],
            units="cm",coordinate_system="tank")
}
test_that("DTW refuses missing source, incompatible units and camera scopes",{
 a <- .cov100_path("A");b <- .cov100_path("B")
 expect_error(aquaTrajectories:::.aqt_single_path(a,max_gap_s=0),"max_gap_s")
 expect_error(aquaTrajectories:::.aqt_single_path(a,max_gap_s=.5),"gaps exceed")
 expect_error(aquaTrajectories:::.aqt_single_path(.cov100_paths()),"exactly one")
 bad <- as.data.frame(a);bad$observed[2] <- FALSE
 q <- aqt_tracks(bad,units="cm",coordinate_system="tank")
 expect_error(aquaTrajectories:::.aqt_single_path(q),"missing or non-observed")
 bad <- as.data.frame(a);bad$x[2] <- NA_real_;bad$y[2] <- NA_real_
 q <- aqt_tracks(bad,units="cm",coordinate_system="tank")
 expect_error(aquaTrajectories:::.aqt_single_path(q),"missing or non-observed")
 wrong <- aqt_tracks(as.data.frame(b),units="m",
                     coordinate_system="tank")
 expect_error(aqt_trajectory_dtw(a,wrong),"share dimension, units")
 expect_error(aqt_trajectory_dtw(a,b,window=-1),"window must")
 expect_error(aqt_trajectory_dtw(a,b,window=1.5),"window must")
 short <- aqt_tracks(as.data.frame(b)[1:2,,drop=FALSE],
          units="cm",coordinate_system="tank")
 expect_error(aqt_trajectory_dtw(a,short,window=0),"band is smaller")
 same <- aqt_trajectory_dtw(a,a,window=0)
 expect_equal(same$distance,0,tolerance=1e-12)
 expect_equal(same$path$index_a,1:4)
 distinct <- aqt_trajectory_dtw(a,b,window=0)
 expect_equal(distinct$distance,4,tolerance=1e-12)
 expect_false(distinct$aligned_clocks)
})
test_that("DTW distance matrix is source-symmetric and rejects one-fish design",{
 tr <- .cov100_paths()
 d <- aqt_trajectory_dtw_matrix(tr,window=0,max_gap_s=1.1)
 expect_equal(unname(d[1,2]),unname(d[2,1]))
 expect_equal(unname(d[1,2]),4,tolerance=1e-12)
 expect_true(all(diag(d)==0))
 expect_identical(attr(d,"aqt_units"),"cm")
 expect_error(aqt_trajectory_dtw_matrix(.cov100_path()),"2 to 40")
 a <- as.data.frame(tr);a$observed[1] <- FALSE
 broken <- aqt_tracks(a,units="cm",coordinate_system="tank")
 expect_error(aqt_trajectory_dtw_matrix(broken),"missing or non-observed")
 expect_equal(aquaTrajectories:::.aqt_long_run_points(logical(0),2L),0L)
 expect_equal(aquaTrajectories:::.aqt_long_run_points(
    c(TRUE,TRUE,FALSE,TRUE),2L),2L)
})
test_that("recurrence explicitly handles absent eligible pairs and undefined fractions", {
 a <- .cov100_path()
 expect_error(aqt_trajectory_recurrence(a,radius=-1),"radius")
 expect_error(aqt_trajectory_recurrence(a,radius=Inf),"radius")
 expect_error(aqt_trajectory_recurrence(a,radius=1,theiler=-1),
              "Invalid Theiler")
 expect_error(aqt_trajectory_recurrence(a,radius=1,min_diagonal=1),
              "Invalid Theiler")
 expect_error(aqt_trajectory_recurrence(a,radius=1,min_vertical=1),
              "Invalid Theiler")
 expect_error(aqt_trajectory_recurrence(a,radius=1,theiler=1.4),
              "finite integers")
 expect_error(aqt_trajectory_recurrence(a,radius=1,store_matrix=NA),
              "store_matrix must")
 any <- aqt_trajectory_recurrence(a,radius=100,theiler=1,
              store_matrix=TRUE)
 expect_s3_class(any,"aqt_recurrence")
 expect_true(any$recurrence_rate>0)
 expect_true(is.matrix(any$recurrence_matrix))
 no <- aqt_trajectory_recurrence(a,radius=0,theiler=1)
 expect_equal(no$recurrence_rate,0)
 expect_true(is.na(no$determinism))
 full_exclusion <- aqt_trajectory_recurrence(a,radius=3,theiler=20)
 expect_equal(full_exclusion$n_pairs,0)
 expect_true(is.na(full_exclusion$recurrence_rate))
 expect_error(aqt_plot_recurrence(no),"store_matrix=TRUE")
 grDevices::pdf(tempfile(fileext=".pdf"))
 on.exit(grDevices::dev.off(),add=TRUE)
 expect_invisible(aqt_plot_recurrence(any))
})
