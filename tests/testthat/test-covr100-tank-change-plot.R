# Visualization of tank replication never treats fish recordings as tanks.
test_that("tank-change plotting refuses missing independent-tank source and nonfinite rows",{
 expect_error(aqt_plot_tank_changes(list()),
              "Expected an aqt_tank_event_contrast result")
 broken <- list(treatment_levels=c("control","treatment"),
    per_tank=data.frame(tank_id=c("C","T"),
       treatment=c("control","treatment"),
       mean_baseline=c(NA_real_,NA_real_),
       mean_response=c(NA_real_,NA_real_)))
 expect_error(aqt_plot_tank_changes(broken),"No finite tank observations")
 valid <- broken
 valid$per_tank$mean_baseline <- c(1,2)
 valid$per_tank$mean_response <- c(2,3)
 grDevices::pdf(tempfile(fileext=".pdf"))
 on.exit(grDevices::dev.off(),add=TRUE)
 out <- aqt_plot_tank_changes(valid)
 expect_equal(nrow(out),2L)
 expect_equal(sort(out$tank_id),c("C","T"))
});
