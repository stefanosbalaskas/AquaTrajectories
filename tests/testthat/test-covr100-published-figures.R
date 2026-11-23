# Scientific publication graphics use independent tanks, declared
# intervention labels and externally surveyed XYZ; no causal claims.
.cov100_pub_occupancy <- function() {
 d <- expand.grid(tank_id=c("C1","C2","T1","T2"),
                  time_s=0:2,KEEP.OUT.ATTRS=FALSE)
 d$scenario <- ifelse(grepl("^C",d$tank_id),"control","treatment")
 d$area_fraction <- pmin(1,.1+.1*d$time_s+
                .03*match(d$tank_id,c("C1","C2","T1","T2")))
 d
}
test_that("sampled occupancy bands use tank-equal weights, not frame pseudoreplication",{
 d <- .cov100_pub_occupancy()
 grDevices::pdf(tempfile(fileext=".pdf"))
 on.exit(grDevices::dev.off(),add=TRUE)
 expect_error(aqt_plot_occupancy_timeseries(d,time_bin_s=0),"time_bin_s")
 bad <- d;bad$area_fraction[1] <- -1
 expect_error(aqt_plot_occupancy_timeseries(bad),"measured proportion")
 bad <- d;bad$scenario[1] <- "another"
 expect_error(aqt_plot_occupancy_timeseries(bad),"multiple scenarios")
 periods <- data.frame(start_s=0,end_s=2,label="logged-period")
 badp <- periods;badp$end_s[1] <- 0
 expect_error(aqt_plot_occupancy_timeseries(d,periods=badp),
              "end_s > start_s")
 seven <- data.frame(tank_id=paste0("T",1:7),scenario=paste0("S",1:7),
                     time_s=0:6,area_fraction=rep(.5,7))
 expect_error(aqt_plot_occupancy_timeseries(seven),"At most six scenarios")
 out <- aqt_plot_occupancy_timeseries(d,time_bin_s=1,band="sd",periods=periods)
 expect_true(all(out$n_tanks==2L))
 expect_true(all(is.finite(out$sd_tanks)))
 expect_false(attr(out,"bands_are_confidence_intervals"))
 expect_true(attr(out,"independent_tank_units_assumed_not_verified"))
 se <- aqt_plot_occupancy_timeseries(d,time_bin_s=1,band="se")
 expect_equal(se$se_tanks,se$sd_tanks/sqrt(2),tolerance=1e-12)
 none <- aqt_plot_occupancy_timeseries(d,time_bin_s=1,band="none")
 expect_equal(nrow(none),6L)
 singleton <- aqt_plot_occupancy_timeseries(d[d$time_s==0,,drop=FALSE],
                 time_bin_s=1,band="none")
 expect_equal(nrow(singleton),2L)
 expect_true(all(singleton$n_tanks==2))
})
test_that("feeding phase graphics require supplied labels and avoid index clipping",{
 d <- data.frame(scenario=c("A","A","B","B"),time_min=c(0,1,0,1),
      fbi=c(.1,.6,.3,.9),phase=c("pre","later","pre","later"))
 grDevices::pdf(tempfile(fileext=".pdf"))
 on.exit(grDevices::dev.off(),add=TRUE)
 expect_error(aqt_plot_feeding_states(d,index_col="scenario"),
              "Column names must be distinct")
 expect_error(aqt_plot_feeding_states(d,phase_col=""),
              "Column names must be distinct")
 expect_error(aqt_plot_feeding_states(d,
        phase_colors=c(pre="red")),"phase_colors must name every")
 expect_error(aqt_plot_feeding_states(d,index_limits=c(1,0)),
              "increasing finite")
 expect_error(aqt_plot_feeding_states(d,index_limits=c(0,NA_real_)),
              "increasing finite")
 expect_error(aqt_plot_feeding_states(d,index_limits=c(0,.5)),
              "do not clip data")
 five <- data.frame(scenario=LETTERS[1:5],time_min=seq_len(5),
       fbi=rep(.5,5),phase="pre")
 expect_error(aqt_plot_feeding_states(five),"At most four scenarios")
 result <- aqt_plot_feeding_states(d,index_limits=NULL)
 expect_equal(sum(result$n_samples),4L)
 expect_true(attr(result,"phase_labels_externally_supplied"))
 expect_false(attr(result,"feeding_index_independently_validated"))
 constant <- data.frame(scenario="A",time_min=0,fbi=.5,phase="pre")
 expect_equal(sum(aqt_plot_feeding_states(constant)$n_samples),1)
})
.cov100_calibration_targets <- function() {
 d <- data.frame(method="MethodA",target_id=paste0("T",1:3),
    partition="holdout",truth_x=c(0,1,2),truth_y=c(0,1,2),
    truth_z=rep(1,3),estimate_x=c(.1,1.2,2.3),
    estimate_y=c(0,1,2),estimate_z=rep(1,3))
 d
}
test_that("physical target comparison reports only independently held-out records",{
 d <- .cov100_calibration_targets()
 grDevices::pdf(tempfile(fileext=".pdf"))
 on.exit(grDevices::dev.off(),add=TRUE)
 expect_error(aqt_plot_calibration_comparison(d,require_holdout=NA),
              "require_holdout must")
 bad <- d;bad$partition[1] <- "unrecorded"
 expect_error(aqt_plot_calibration_comparison(bad),
              "partition must be either")
 bad <- d;bad$partition <- "fit"
 expect_error(aqt_plot_calibration_comparison(bad),
              "No independently held-out")
 bad <- rbind(d,transform(d[1,,drop=FALSE],partition="fit"))
 expect_error(aqt_plot_calibration_comparison(bad),
              "leak from calibration fit")
 bad <- rbind(d,d[1,,drop=FALSE])
 expect_error(aqt_plot_calibration_comparison(bad),
              "Only one record per")
 bad <- do.call(rbind,lapply(1:5,function(j)
                transform(d[1,,drop=FALSE],method=paste0("M",j))))
 expect_error(aqt_plot_calibration_comparison(bad),
              "Select at most four")
 fitless <- d[,setdiff(names(d),"partition"),drop=FALSE]
 result <- aqt_plot_calibration_comparison(fitless,
             require_holdout=FALSE,units="cm")
 expect_equal(result$n_targets,3L)
 expect_equal(result$mean_error,.2,tolerance=1e-12)
 expect_equal(result$rmse_3d,sqrt(mean(c(.1,.2,.3)^2)),
             tolerance=1e-12)
 expect_false(attr(result,"independent_physical_survey_verified"))
 expect_false(attr(result,"fit_targets_excluded"))
 qualified <- aqt_plot_calibration_comparison(d,require_holdout=TRUE)
 expect_true(attr(qualified,"fit_targets_excluded"))
})
