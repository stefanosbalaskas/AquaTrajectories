# Publication graphics on synthetic headings and speed, with independent
# tank denominators, explicit units and fully specified missing-data cases.
.cov100_pub_speed <- function() {
 data.frame(tank_id=rep(c("T1","T2"),each=6),
    time_s=rep(c(-2,-1,0,1,2,3),2),
    speed=c(1,1.5,2,3,3.5,4,2,2.5,3,4,4.5,5))
}
test_that("published speed-response graphics require units and paired tanks", {
 d <- .cov100_pub_speed()
 grDevices::pdf(tempfile(fileext=".pdf"))
 on.exit(grDevices::dev.off(),add=TRUE)
 call <- function(x=d,event_time_s=0,baseline_s=c(-3,0),
                 response_s=c(0,4),speed_unit="cm/s",...)
    aqt_plot_speed_response(x,event_time_s=event_time_s,
      baseline_s=baseline_s,response_s=response_s,speed_unit=speed_unit,...)
 expect_error(call(baseline_s=0),"finite increasing pairs")
 expect_error(call(response_s=c(2,1)),"finite increasing pairs")
 expect_error(call(response_s=c(Inf,3)),"finite increasing pairs")
 expect_error(call(baseline_s=c(-3,1)),"cannot overlap")
 expect_error(aqt_plot_speed_response(d,event_time_s=0),"Specify measured speed_unit")
 expect_error(call(time_bin_s=0),"time_bin_s must")
 expect_error(call(max_gap_s=0),"max_gap_s must")
 expect_error(call(event_time_s=Inf),"event_time_s must")
 bad <- d;bad$speed <- as.character(bad$speed)
 expect_error(call(x=bad),"speed must be numeric")
 bad <- d;bad$speed <- -1
 expect_error(call(x=bad),"No finite nonnegative speed")
 expect_error(call(event_time_s=100),"No speed measurements within")
 gap <- d[d$tank_id=="T1" & d$time_s<0 |
           d$tank_id=="T2" & d$time_s>=0,,drop=FALSE]
 expect_error(call(x=gap),"No independent tank has valid")
 res <- call()
 expect_equal(nrow(res$summary),2L)
 expect_equal(res$summary$n_tanks,c(2,2))
 expect_true(all(is.finite(res$summary$sd_tanks)))
 expect_false(attr(res,"significance_test_performed"))
 just_one <- d[d$tank_id=="T1",,drop=FALSE]
 single <- call(x=just_one)
 expect_equal(single$summary$n_tanks,c(1,1))
 expect_true(all(is.na(single$summary$sd_tanks)))
})
test_that("publication heading rose declares handedness, weights and source images", {
 d <- data.frame(condition=c("A","A","B","B"),
          heading_rad=c(0,pi/2,pi,NA_real_),weight=c(1,2,1,1))
 grDevices::pdf(tempfile(fileext=".pdf"))
 on.exit(grDevices::dev.off(),add=TRUE)
 call <- function(x=d,...)aqt_plot_heading_rose(x,...)
 expect_error(call(bins=3),"bins must")
 expect_error(call(bins=73),"bins must")
 expect_error(call(clockwise=1),"clockwise must")
 expect_error(call(clockwise=NA),"clockwise must")
 expect_error(call(zero_offset_rad=Inf),"zero_offset_rad must")
 bad <- d;bad$heading_rad <- as.character(bad$heading_rad)
 expect_error(call(x=bad),"heading_rad must be numeric")
 bad <- d;bad$heading_rad[1] <- Inf
 expect_error(call(x=bad),"heading_rad must be numeric")
 expect_error(call(weight_col="nonexistent"),"Missing observation weight")
 bad <- d;bad$weight[1] <- -1
 expect_error(call(x=bad,weight_col="weight"),"Weights cannot be negative")
 bad <- d;bad$weight[1] <- NA_real_
 expect_error(call(x=bad,weight_col="weight"),"finite numeric")
 bad <- d;bad$heading_rad <- NA_real_
 expect_error(call(x=bad),"No finite headings")
 d7 <- data.frame(condition=LETTERS[1:7],
                  heading_rad=seq(0,pi,length.out=7))
 expect_error(call(x=d7),"At most six conditions")
 d5 <- d7[1:5,,drop=FALSE]
 named_images <- setNames(rep(list(matrix("#FF0000",1,1)),5),LETTERS[1:5])
 expect_error(call(x=d5,frame_rasters=named_images),
              "at most four conditions")
 expect_error(call(frame_rasters=list()),"named list covering")
 valid <- list(A=matrix("#FF0000",1,1),B=matrix("#0000FF",1,1))
 result <- call(frame_rasters=valid,scale="count",clockwise=TRUE,
                weight_col="weight",bins=12,zero_offset_rad=.1)
 expect_equal(nrow(result),24L)
 expect_false(attr(result,"3d_orientation_inferred"))
 expect_equal(attr(result,"excluded_missing_or_zero_weight"),1L)
 ordinary <- call(scale="fraction",bins=4)
 expect_true(all(ordinary$proportion>=0 & ordinary$proportion<=1))
})
test_that("private publication helpers reject malformed physical axes", {
 expect_equal(aquaTrajectories:::.aqt_pub_panels(1),c(1L,1L))
 expect_equal(aquaTrajectories:::.aqt_pub_panels(3),c(2,2))
 expect_error(aquaTrajectories:::.aqt_pub_data(list(),"x","Fixture"),"Fixture")
 expect_error(aquaTrajectories:::.aqt_pub_id(" ","scope"),"scope must")
 expect_error(aquaTrajectories:::.aqt_pub_number(0,"positive",positive=TRUE),
              "positive must")
 expect_error(aquaTrajectories:::.aqt_pub_column_numeric(
    data.frame(x=c(1,NA_real_)),"x"),"finite numeric")
 xyz <- matrix(c(0,0,0,1,1,1),ncol=3,byrow=TRUE)
 bounds <- rbind(c(0,0,0),c(2,2,2))
 a <- aquaTrajectories:::.aqt_pub_project_xyz(xyz,bounds)
 expect_equal(dim(a),c(2L,2L))
 expect_error(aquaTrajectories:::.aqt_pub_project_xyz(xyz[,1:2],bounds),
              "Expected finite three-column")
 expect_error(aquaTrajectories:::.aqt_pub_project_xyz(xyz,bounds[1,,drop=FALSE]),
              "Invalid XYZ bounds")
})