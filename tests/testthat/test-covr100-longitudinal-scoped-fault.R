# Fully source-declared synthetic longitudinal tank design, independent of
# testthat test-file execution order.
.cov100_longitudinal_grid <- function() {
  tanks <- c("C1","C2","C3","T1","T2","T3")
  d <- do.call(rbind,lapply(tanks,function(tank)
    do.call(rbind,lapply(1:2,function(fish) {
      time <- 0:10
      data.frame(session_id=tank,camera_id="TOP",
        track_id=paste0("F",fish),time_s=time,
        value=1+.1*fish+.03*time+.1*match(tank,tanks)+
          if(grepl("^T",tank)) .2*(time>=5) else 0,
        observed=TRUE,tank_id=tank,
        treatment=if(grepl("^T",tank))"treatment" else "control")
    }))))
  events <- data.frame(session_id=tanks,event_id="feed",
                       start_s=5,end_s=5)
  aqt_functional_event_grid(d,events,outcome="value",
     grid_s=-5:5,max_gap_s=1.1)
}
# Source-unit longitudinal design is meaningful only for complete,
# equally spaced within-fish curves and one session/event per tank.
test_that("strict functional longitudinal preparation rejects nonfinite grids before fitting",{
 g <- .cov100_longitudinal_grid()
 bad <- g
 bad$time_relative_s[1] <- Inf
 expect_error(aqt_functional_longitudinal_prepare(bad),
              "Functional model time grid must be finite")
})
test_that("two complete fish sessions may not masquerade as one independently treated tank",{
 g <- .cov100_longitudinal_grid()
 bad <- g
 bad$session_id[bad$tank_id=="C1" & bad$track_id=="F2"] <- "UNRELATED_SESSION"
 expect_error(aqt_functional_longitudinal_prepare(bad),
              "Each independently treated tank requires one session and event")
})
