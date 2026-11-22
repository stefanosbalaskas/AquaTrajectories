# Physical speed-response and geometry geometry checks use synthetic tanks,
# not tracked fish/frames as independent treatment units.
.cov100_phys_tank_tracks <- function(unit="cm",n_tanks=2) {
 d <- do.call(rbind,lapply(seq_len(n_tanks),function(i)
   data.frame(session_id=paste0("T",i),camera_id="C",
      track_id="F",tank_id=paste0("T",i),
      time_s=seq(0,.5,by=.1),
      x=(0:5)*(.5+i*.1),y=rep(i,6),observed=TRUE)))
 aqt_tracks(d,units=unit,coordinate_system=if(unit=="px")"image" else "tank")
}
test_that("physical trajectory speed plots infer measured units but refuse pixel velocity units",{
 tr <- .cov100_phys_tank_tracks()
 plot <- tempfile(fileext=".pdf")
 grDevices::pdf(plot,width=10,height=6)
 on.exit({grDevices::dev.off();unlink(plot)},add=TRUE)
 result <- aqt_plot_speed_response(tr,event_time_s=.25,
   baseline_s=c(-.3,0),response_s=c(0,.4),
   max_gap_s=.11,time_bin_s=.1)
 expect_equal(result$summary$n_tanks,c(2L,2L))
 expect_true(all(result$summary$speed_unit=="cm/s"))
 expect_true(all(is.finite(result$summary$mean_speed)))
 expect_true(all(is.finite(result$summary$sd_tanks)))
 expect_false(attr(result,"independent_tank_replication_verified"))
 expect_false(attr(result,"significance_test_performed"))
 expect_error(aqt_plot_speed_response(
      .cov100_phys_tank_tracks("px"),event_time_s=.25,
      baseline_s=c(-.3,0),response_s=c(0,.4)),
      "Specify speed_unit for nonphysical")
 one <- aqt_plot_speed_response(.cov100_phys_tank_tracks(n_tanks=1),
      event_time_s=.25,baseline_s=c(-.3,0),
      response_s=c(0,.4),max_gap_s=.11,time_bin_s=.1)
 expect_equal(one$summary$n_tanks,c(1L,1L))
 expect_true(all(is.na(one$summary$sd_tanks)))
})
test_that("school pair helper handles true zero, one and three fish without inventing pairs",{
 pairs <- aquaTrajectories:::.aqt_group_pairs
 none <- pairs(data.frame(x=numeric()),"x")
 expect_equal(dim(none),c(0L,2L))
 one <- pairs(data.frame(x=1),"x")
 expect_equal(dim(one),c(0L,2L))
 three <- pairs(data.frame(x=1:3),"x")
 expect_equal(dim(three),c(2L,3L))
 expect_equal(ncol(three),3L)
 expect_equal(nrow(three),2L)
})
test_that("nonadjacent source frames remain discontinuous under all QC sensitivity policies",{
 d <- as.data.frame(.cov100_phys_tank_tracks(n_tanks=1))
 d$frame_id <- c(0,1,3,4,5,6)
 tr <- aqt_tracks(d,units="cm",coordinate_system="tank")
 s <- aqt_qc_sensitivity(tr,gap_limits_s=c(.11,.2),
           speed_limits=c(2,20),step_limits=c(.1,2))
 expect_equal(nrow(s$policies),8L)
 expect_equal(nrow(s$ledger),48L)
 expect_equal(nrow(s$summary),8L)
 expect_true(all(s$ledger$reason[s$ledger$input_row==3] ==
                  "nonadjacent_source_frame"))
 expect_false(any(s$ledger$step_eligible[s$ledger$input_row==3]))
 expect_true(any(s$ledger$reason=="step_threshold"))
 expect_true(any(s$ledger$reason=="speed_threshold"))
 expect_error(aqt_qc_sensitivity(tr,gap_limits_s=c(.1,.1)),
              "unique positive numeric values")
 empty <- aqt_tracks(as.data.frame(tr)[FALSE,,drop=FALSE],
                units="cm",coordinate_system="tank")
 q <- aqt_qc_sensitivity(empty,gap_limits_s=.2)
 expect_equal(nrow(q$ledger),0L)
 expect_equal(nrow(q$summary),0L)
})
