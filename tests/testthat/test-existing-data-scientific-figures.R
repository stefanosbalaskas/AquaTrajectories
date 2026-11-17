# Mathematical checks of two additional native scientific figure families.
# These are invented analytic fixtures; no fish-video accuracy is inferred.
test_that("heading rose exact quadrants sum to 100 percent", {
  headings <- data.frame(condition = rep("Controlled",4),
                         heading_rad = c(0, pi/2, pi, 3*pi/2))
  figure <- tempfile(fileext = ".pdf")
  grDevices::pdf(figure)
  tryCatch({
    result <- aqt_plot_heading_rose(headings, bins = 4L, scale = "fraction")
    expect_equal(result$n_observations, rep(1L, 4L))
    expect_equal(result$proportion, rep(0.25,4L), tolerance = 1e-12)
    expect_equal(sum(result$proportion), 1)
    expect_false(attr(result,"3d_orientation_inferred"))
  }, finally = grDevices::dev.off())
  expect_gt(file.info(figure)$size, 1000)
})

test_that("occupancy figure first averages frames within each independent tank", {
  x <- data.frame(
    scenario = "A",
    tank_id = rep(c("T01","T02"), each = 4L),
    time_s = rep(c(0,0.2,1,1.2),2L),
    area_fraction = c(0.2,0.4,0.3,0.5, 0.6,0.8,0.5,0.9))
  figure <- tempfile(fileext = ".pdf")
  grDevices::pdf(figure)
  tryCatch({
    out <- aqt_plot_occupancy_timeseries(x,time_bin_s=1,band="se")
    at0 <- out[out$time_s == 0,,drop=FALSE]
    expect_equal(nrow(at0), 1)
    # Tank 1 contributes 0.3, tank 2 contributes 0.7.
    expect_equal(at0$mean_fraction,0.5,tolerance=1e-12)
    expect_equal(at0$sd_tanks,sqrt(0.08),tolerance=1e-12)
    expect_equal(at0$se_tanks,0.2,tolerance=1e-12)
    expect_equal(at0$n_tanks,2)
    expect_equal(at0$n_frames,4)
    expect_false(attr(out,"bands_are_confidence_intervals"))
  },finally=grDevices::dev.off())
  expect_gt(file.info(figure)$size,1000)
})
