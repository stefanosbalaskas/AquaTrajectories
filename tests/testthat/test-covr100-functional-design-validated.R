# Additional scientific QC branches: no source excluded, no biological claims.
.cov100_func_fixture <- function() {
  tanks <- c("C1","C2","C3","T1","T2","T3")
  d <- do.call(rbind,lapply(tanks,function(tank)
    do.call(rbind,lapply(1:2,function(fish) {
      time <- 0:10
      data.frame(session_id=tank,camera_id="TOP",track_id=paste0("F",fish),
        time_s=time,
        value=1+.1*fish+.03*time+.1*match(tank,tanks)+
          if(grepl("^T",tank)) .2*(time>=5) else 0,
        observed=TRUE,tank_id=tank,
        treatment=if(grepl("^T",tank))"treatment" else "control")
    }))))
  events <- data.frame(session_id=tanks,event_id="feed",start_s=5,end_s=5)
  list(d=d,events=events)
}
.cov100_func_grid <- function() {
 f <- .cov100_func_fixture()
 aqt_functional_event_grid(f$d,f$events,outcome="value",
    grid_s=-5:5,max_gap_s=1.1)
}
test_that("functional grid refuses scientifically inconsistent source and metadata", {
 f <- .cov100_func_fixture()
 fun <- function(d=f$d,ev=f$events,grid=-5:5,...)
   aqt_functional_event_grid(d,ev,"value",grid_s=grid,...)
 expect_error(fun(d=list()),"Expected nonempty scoped")
 expect_error(fun(d=f$d[0,,drop=FALSE]),"Expected nonempty scoped")
 bad <- f$d;bad$value <- as.character(bad$value)
 expect_error(fun(d=bad),"numeric outcome")
 bad <- f$d;bad$time_s[1] <- Inf
 expect_error(fun(d=bad),"Timestamps must be finite")
 bad <- f$d;bad$value[1] <- Inf
 expect_error(fun(d=bad),"outcomes cannot be infinite")
 expect_error(fun(grid=0),"strictly increasing finite")
 expect_error(fun(grid=c(0,0)),"strictly increasing finite")
 expect_error(fun(grid=c(0,NA_real_)),"strictly increasing finite")
 expect_error(fun(grid=seq_len(501)),"strictly increasing finite")
 expect_error(fun(max_gap_s=0),"positive finite recording")
 expect_error(fun(max_gap_s=Inf),"positive finite recording")
 bad <- f$d;bad$observed <- as.integer(bad$observed)
 expect_error(fun(d=bad),"nonmissing logical")
 bad <- f$d;bad$observed[1] <- NA
 expect_error(fun(d=bad),"nonmissing logical")
 bad <- f$d;bad$tank_id[1] <- ""
 expect_error(fun(d=bad),"Identity, treatment and tank")
 bad <- f$d;bad$track_id[1] <- NA_character_
 expect_error(fun(d=bad),"Identity, treatment and tank")
 bad <- f$d;bad$time_s[2] <- bad$time_s[1]
 expect_error(fun(d=bad),"Repeated timestamps")
 ev <- f$events[-1,,drop=FALSE]
 expect_error(fun(ev=ev),"explicitly logged event")
 ev <- rbind(f$events,f$events[1,,drop=FALSE])
 expect_error(fun(ev=ev),"Duplicate event per session|One event per session")
 bad <- f$d;bad$treatment[1] <- "treatment"
 expect_error(fun(d=bad),"Tank and treatment cannot change")
 no_flags <- f$d;no_flags$observed <- NULL
 g <- fun(d=no_flags)
 expect_true(all(g$supported))
 expect_equal(nrow(aqt_functional_coverage(g)),11)
 expect_error(aqt_functional_coverage(list()),"Expected an aqt_functional_event_grid")
})
test_that("functional event grid preserves missingness and forbids gap bridging", {
 f <- .cov100_func_fixture()
 d <- f$d
 d$observed[d$session_id=="C1" & d$track_id=="F1" & d$time_s==5] <- FALSE
 out <- aqt_functional_event_grid(d,f$events,"value",
    grid_s=c(-1,0,.5),max_gap_s=1.1)
 missed <- out[out$session_id=="C1" & out$track_id=="F1",]
 expect_false(missed$supported[2])
 expect_false(missed$supported[3])
 sparse <- aqt_functional_event_grid(f$d,f$events,"value",
    grid_s=c(-1.5,-1,0),max_gap_s=.25)
 expect_false(any(sparse$supported[sparse$time_relative_s==-1.5]))
 expect_true(all(sparse$supported[sparse$time_relative_s==-1]))
})
test_that("functional independent-tank contrasts enforce replication and per-tank coverage", {
 g <- .cov100_func_grid()
 call <- function(x=g,draws=100,...)aqt_functional_tank_contrast(x,draws=draws,...)
 expect_error(call(x=data.frame()),"requires an event grid")
 expect_error(call(treatment_levels="control"),"two distinct treatment_levels")
 expect_error(call(treatment_levels=c("control","control")),"two distinct treatment_levels")
 expect_error(call(min_fish_fraction=0),"min_fish_fraction")
 expect_error(call(min_fish_fraction=1.1),"min_fish_fraction")
 expect_error(call(draws=99),"draws must")
 expect_error(call(draws=5001),"draws must")
 expect_error(call(level=0),"level must")
 expect_error(call(level=1),"level must")
 expect_error(call(seed=-1),"seed must")
 expect_error(call(seed=2147483648),"seed must")
 expect_error(call(treatment_levels=c("control","absent")),"Exactly two treatments")
 bad <- g;bad$event_id[bad$tank_id=="C1"][1] <- "different"
 expect_error(call(x=bad),"One independent event/session per tank")
 bad <- rbind(g,g[1,,drop=FALSE]);class(bad) <- class(g)
 expect_error(call(x=bad),"Duplicate fish/grid")
 bad <- g[!(g$tank_id=="C1" & g$time_relative_s==-5),,drop=FALSE]
 class(bad) <- class(g)
 expect_error(call(x=bad),"Inconsistent functional time support")
 bad <- g;bad$supported[bad$tank_id=="C1" & bad$time_relative_s==0] <- FALSE
 expect_error(call(x=bad),"Insufficient independent-tank fish coverage")
 set.seed(307);initial <- .Random.seed
 result <- call()
 expect_identical(.Random.seed,initial)
 expect_equal(result$design_audit$n_tanks,c(3,3))
 expect_equal(nrow(result$curve),11)
 expect_false(result$calibrated_coverage)
 expect_false(result$causal_identification)
})
test_that("strict longitudinal design rejects incomplete or pseudoreplicated curves", {
 g <- .cov100_func_grid()
 fun <- function(x=g,...)aqt_functional_longitudinal_prepare(x,...)
 expect_error(fun(x=list()),"Expected an event-aligned fish grid")
 expect_error(fun(treatment_levels="control"),"Exactly two distinct ordered")
 expect_error(fun(treatment_levels=c("control","control")),"Exactly two distinct ordered")
 bad <- g;bad$supported[1] <- FALSE
 expect_error(fun(x=bad),"fully observed finite")
 bad <- g;bad$time_relative_s[bad$time_relative_s==5] <- 5.5
 expect_error(fun(x=bad),"uniformly spaced")
 bad <- g[-1,,drop=FALSE];class(bad) <- class(g)
 expect_error(fun(x=bad),"identical complete event-relative grids")
 bad <- rbind(g,g[1,,drop=FALSE]);class(bad) <- class(g)
 expect_error(fun(x=bad),"Duplicate fish-time")
 bad <- g;bad$event_id[1] <- "OTHER"
 expect_error(fun(x=bad),"stable tank, treatment and event")
 bad <- g;bad$session_id[1] <- "OTHER"
 expect_error(fun(x=bad),"identical complete event-relative grids|one session and event")
 bad <- g;bad$track_id[1] <- ""
 expect_error(fun(x=bad),"Fish, tank and event IDs")
 one_fish <- g[g$track_id=="F1",,drop=FALSE];class(one_fish) <- class(g)
 expect_error(fun(x=one_fish),"At least two observed fish")
 four_tanks <- g[g$tank_id %in% c("C1","C2","T1","T2"),,drop=FALSE]
 class(four_tanks) <- class(g)
 expect_error(fun(x=four_tanks),">=3 independent tanks")
 prepared <- fun()
 expect_true(isTRUE(attr(prepared,"aqt_design_strict")))
 expect_error(aqt_functional_longitudinal_fit(list()),"prepare first")
 expect_error(aqt_functional_longitudinal_fit(prepared,spline_df=0),"spline_df")
 expect_error(aqt_functional_longitudinal_fit(prepared,spline_df=7),"spline_df")
 expect_error(aqt_functional_longitudinal_fit(prepared,residual="unknown"),"should be one of")
})
