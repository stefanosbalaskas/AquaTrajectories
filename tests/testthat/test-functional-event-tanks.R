.aqt_functional_fixture <- function() {
  tanks <- c("C1","C2","T1","T2")
  d <- do.call(rbind,lapply(tanks,function(tank) {
    do.call(rbind,lapply(1:2,function(fish) {
      t <- 0:6
      data.frame(session_id=tank,camera_id="TOP",
        track_id=paste0("F",fish),time_s=t,
        speed=1+(substr(tank,1,1)=="T")*as.integer(t>=3),
        observed=rep(TRUE,length(t)),tank_id=tank,
        treatment=if(substr(tank,1,1)=="T")"treatment" else "control")
    }))
  }))
  list(data=d,events=data.frame(session_id=tanks,event_id="feed",
             start_s=3,end_s=3),
       grid=c(-2,-1,0,1,2))
}

test_that("functional event grid exactly aligns observed fish with an event", {
  f <- .aqt_functional_fixture()
  g <- aqt_functional_event_grid(f$data,f$events,
          outcome="speed",grid_s=f$grid,max_gap_s=1.1)
  expect_s3_class(g,"aqt_functional_event_grid")
  expect_equal(nrow(g),4*2*5)
  expect_true(all(g$supported))
  expect_equal(sort(unique(g$time_relative_s)),f$grid)
  expect_equal(unique(g$value[g$treatment=="control"]),1)
  expect_equal(unique(g$value[g$treatment=="treatment" &
                              g$time_relative_s<0]),1)
  expect_equal(unique(g$value[g$treatment=="treatment" &
                              g$time_relative_s>=0]),2)
  coverage <- aqt_functional_coverage(g)
  expect_equal(coverage$n_fish,rep(8,5))
  expect_equal(coverage$fraction_supported,rep(1,5))
  expect_equal(coverage$n_sessions,rep(4,5))
})

test_that("tank functional contrast weights tanks, not frames or fish", {
  f <- .aqt_functional_fixture()
  g <- aqt_functional_event_grid(f$data,f$events,
          outcome="speed",grid_s=f$grid,max_gap_s=1.1)
  set.seed(101);prior <- .Random.seed
  ans <- aqt_functional_tank_contrast(g,draws=100,seed=32)
  expect_identical(.Random.seed,prior)
  expect_equal(nrow(ans$per_tank),4*5)
  expect_equal(ans$curve$contrast,c(0,0,1,1,1))
  expect_equal(ans$curve$simultaneous_lower,ans$curve$contrast)
  expect_equal(ans$curve$simultaneous_upper,ans$curve$contrast)
  expect_equal(ans$design_audit$n_tanks,c(2,2))
  expect_false(ans$calibrated_coverage)
  expect_false(ans$causal_identification)
  expect_false(ans$measurement_error_modeled)
})

test_that("functional grid refuses interpolation across gaps and missing frames", {
  f <- .aqt_functional_fixture()
  d <- f$data
  d$observed[d$session_id=="T2" & d$track_id=="F1" &
               d$time_s==3] <- FALSE
  g <- aqt_functional_event_grid(d,f$events,"speed",
        grid_s=c(-.5,0,.5),max_gap_s=1.1)
  x <- g[g$session_id=="T2" & g$track_id=="F1",]
  expect_true(all(!x$supported))
  expect_true(all(is.na(x$value)))
  expect_error(aqt_functional_tank_contrast(g,draws=100),
               "Insufficient independent-tank fish coverage")
  alt <- aqt_functional_tank_contrast(g,draws=100,
                                     min_fish_fraction=.5)
  expect_equal(alt$curve$contrast,c(.5,1,1))
  g2 <- aqt_functional_event_grid(f$data,f$events,"speed",
        grid_s=c(-1.5,-1,0),max_gap_s=.25)
  expect_true(all(!g2$supported[g2$time_relative_s==-1.5]))
  expect_true(all(g2$supported[g2$time_relative_s %in% c(-1,0)]))
})

test_that("independent-tank design and source structure are guarded", {
  f <- .aqt_functional_fixture()
  d <- f$data
  d$treatment[1] <- "treatment"
  expect_error(aqt_functional_event_grid(d,f$events,"speed",
        grid_s=f$grid,max_gap_s=1.1),
        "Tank and treatment cannot change")
  g <- aqt_functional_event_grid(f$data,f$events,"speed",
        grid_s=f$grid,max_gap_s=1.1)
  g$treatment[1] <- "treatment"
  expect_error(aqt_functional_tank_contrast(g,draws=100),
        "Treatment varies within tank")
  expect_error(aqt_functional_event_grid(f$data,
      rbind(f$events,f$events[1,]),grid_s=f$grid),
      "One event per session")
  expect_error(aqt_functional_event_grid(f$data,f$events,
      grid_s=c(0,0,1)), "strictly increasing")
  d <- f$data
  d$time_s[2] <- d$time_s[1]
  expect_error(aqt_functional_event_grid(d,f$events,"speed",
       grid_s=f$grid,max_gap_s=1.1),"Repeated timestamps")
})


test_that("interpolation never straddles event onset or drops unmatched sessions", {
  f <- .aqt_functional_fixture()
  d <- f$data
  # Two samples directly around event onset but none at onset.
  single <- d[d$session_id=="C1" & d$track_id=="F1",]
  single <- single[single$time_s %in% c(2,4),]
  single$time_s <- c(2.8,3.2)
  single$speed <- c(1,9)
  event <- f$events[f$events$session_id=="C1",]
  g <- aqt_functional_event_grid(single,event,"speed",
        grid_s=c(-.2,0,.2),max_gap_s=.5)
  expect_equal(g$value[1L],1)
  expect_false(g$supported[2L])
  expect_equal(g$value[3L],9)
  expect_error(aqt_functional_event_grid(f$data,event,
      outcome="speed",grid_s=c(-1,0,1),max_gap_s=1.1),
      "All supplied fish sessions")
})
