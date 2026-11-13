test_that("feeding panels only use supplied index and phase labels",{
  d <- expand.grid(scenario=c("normal","overfed","reduced","none"),
                   time_min=c(-5,0,5,10,20),KEEP.OUT.ATTRS=FALSE)
  d$fbi <- .3+.2*(d$time_min>=0)
  d$phase <- ifelse(d$time_min<0,"pre",
             ifelse(d$time_min==0,"onset",
             ifelse(d$time_min<=10,"later","post")))
  f <- tempfile(fileext=".pdf")
  grDevices::pdf(f,width=11,height=8)
  tryCatch({
    result <- aqt_plot_feeding_states(d)
    expect_true(is.data.frame(result))
    expect_equal(sum(result$n_samples),nrow(d))
    expect_true(attr(result,"phase_labels_externally_supplied"))
    expect_false(attr(result,"feeding_index_independently_validated"))
  },finally=grDevices::dev.off())
  expect_true(file.exists(f));unlink(f)
  expect_error(aqt_plot_feeding_states(transform(d,fbi=2)),
               "extends beyond index_limits")
  expect_error(aqt_plot_feeding_states(transform(d,phase="unknown")),
               "phase_colors")
  expect_error(aqt_plot_feeding_states(rbind(d,transform(d,
               scenario="fifth"))),"At most four")
})

test_that("calibration panels exclude fitting targets and score XYZ in units",{
  d <- data.frame(
    method=rep(c("ray","refractive"),each=4L),
    target_id=rep(c("F1","T1","T2","T3"),2L),
    partition=rep(c("fit","holdout","holdout","holdout"),2L),
    truth_x=rep(c(0,1,2,3),2L),truth_y=rep(c(0,1,1,1),2L),
    truth_z=rep(c(1,1,2,3),2L),
    estimate_x=rep(c(0,1.05,2.1,3.15),2L),
    estimate_y=rep(c(0,1,1,1),2L),
    estimate_z=rep(c(1,1,2,3),2L))
  f <- tempfile(fileext=".pdf");grDevices::pdf(f,width=12,height=9)
  tryCatch({
    z <- aqt_plot_calibration_comparison(d,units="cm")
    expect_equal(z$n_targets,c(3L,3L))
    expect_equal(z$rmse_3d,rep(sqrt(mean(c(.05,.10,.15)^2)),2),tolerance=1e-10)
    expect_true(attr(z,"fit_targets_excluded"))
    expect_false(attr(z,"independent_physical_survey_verified"))
  },finally=grDevices::dev.off())
  unlink(f)
  leak <- rbind(d,d[2L,,drop=FALSE])
  leak$partition[nrow(leak)] <- "fit"
  expect_error(aqt_plot_calibration_comparison(leak),"leak")
  expect_error(aqt_plot_calibration_comparison(subset(d,
               partition=="fit")),"No independently held-out")
  x <- d;x$estimate_x[3L] <- Inf
  expect_error(aqt_plot_calibration_comparison(x),
               "finite numeric")
})

test_that("occupancy uses tank replication, not number of fish frames",{
  d <- expand.grid(scenario=c("feed","control"),
                   replicate=1:2,time_s=0:4,
                   KEEP.OUT.ATTRS=FALSE)
  d$tank_id <- paste(d$scenario,d$replicate,sep="_")
  d$area_fraction <- ifelse(d$replicate==1L,.2,.6)
  d_extra <- d[d$replicate==1L & d$time_s==2,,drop=FALSE]
  x <- rbind(d,d_extra,d_extra,d_extra)
  f <- tempfile(fileext=".pdf")
  grDevices::pdf(f,width=11,height=9)
  tryCatch({
    z <- aqt_plot_occupancy_timeseries(x,time_bin_s=1,
      periods=data.frame(start_s=1,end_s=2,label="Stimulus"))
    expect_true(all(z$n_tanks==2L))
    expect_true(all(abs(z$mean_fraction-.4)<1e-10))
    expect_true(all(abs(z$sd_tanks-sqrt(.08))<1e-10))
    expect_false(attr(z,"bands_are_confidence_intervals"))
  },finally=grDevices::dev.off())
  unlink(f)
  x$area_fraction[1] <- 2
  expect_error(aqt_plot_occupancy_timeseries(x),"between 0 and 1")
  d$tank_id <- paste0("T",d$replicate)
  expect_error(aqt_plot_occupancy_timeseries(d),"multiple scenarios")
})

test_that("speed panels compare equally weighted paired tank epochs",{
  d <- expand.grid(tank_id=c("T01","T02"),time_s=-5:5,
                   KEEP.OUT.ATTRS=FALSE)
  d$speed <- ifelse(d$time_s<0,
          ifelse(d$tank_id=="T01",1,3),
          ifelse(d$tank_id=="T01",2,4))
  f <- tempfile(fileext=".pdf");grDevices::pdf(f,width=12,height=6)
  tryCatch({
    z <- aqt_plot_speed_response(d,event_time_s=0,
      baseline_s=c(-5,0),response_s=c(0,6),
      speed_unit="cm/s",time_bin_s=1)
    expect_equal(z$summary$mean_speed,c(2,3))
    expect_equal(z$summary$n_tanks,c(2L,2L))
    expect_false(attr(z,"significance_test_performed"))
    expect_equal(nrow(z$per_tank_epoch),2L)
  },finally=grDevices::dev.off())
  unlink(f)
  expect_error(aqt_plot_speed_response(d,event_time_s=0),
               "Specify measured speed_unit")
  expect_error(aqt_plot_speed_response(d,event_time_s=0,
               speed_unit="cm/s",baseline_s=c(-5,2)),
               "cannot overlap")
})

test_that("heading rose provides fixed bins and optional supplied image",{
  d <- data.frame(
    condition=rep(c("synchronized","threat"),each=6),
    heading_rad=c(rep(0,5),pi/3,rep(pi,5),pi/4))
  f <- tempfile(fileext=".pdf")
  frame <- grDevices::as.raster(matrix(
    rep(c("#112233","#445566","#AABBCC","#FFFFFF"),4L),4,4))
  grDevices::pdf(f,width=11,height=8)
  tryCatch({
    z <- aqt_plot_heading_rose(d,bins=8L)
    expect_equal(nrow(z),16L)
    expect_true(all(abs(tapply(z$proportion,z$condition,sum)-1)<1e-10))
    expect_true(all(z$circular_resultant_length>=0 &
                    z$circular_resultant_length<=1+1e-12))
    expect_false(attr(z,"3d_orientation_inferred"))
    images <- list(synchronized=frame,threat=frame)
    zz <- aqt_plot_heading_rose(d,bins=8L,clockwise=TRUE,
        frame_rasters=images,scale="count")
    expect_equal(nrow(zz),16L)
  },finally=grDevices::dev.off())
  unlink(f)
  expect_error(aqt_plot_heading_rose(d,bins=2),"bins")
  expect_error(aqt_plot_heading_rose(d,
               frame_rasters=list(synchronized=frame)),
               "covering every condition")
  expect_error(aqt_plot_heading_rose(transform(d,heading_rad=Inf)),
               "not Inf")
})
