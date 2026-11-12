.aqt_longitudinal_fixture <- function(n_tanks=8L) {
  tanks <- paste0("T",seq_len(n_tanks))
  d <- do.call(rbind,lapply(seq_len(n_tanks),function(i) {
    tr <- if(i<=n_tanks/2)"control" else "treatment"
    do.call(rbind,lapply(1:3,function(f) {
      time <- 0:10
      event_relative <- time-5
      data.frame(session_id=tanks[i],camera_id="REFRACTIVE3D",
        track_id=paste0("F",f),time_s=time,
        value=2+.16*i+.13*f+.14*sin(time*.7+i*.4+f*.2)+
          .09*cos(time*.32+f)+.012*time+
          if(tr=="treatment") .4*event_relative^2/25 else 0,
        observed=TRUE,tank_id=tanks[i],treatment=tr)
    }))
  }))
  events <- data.frame(session_id=tanks,event_id="feed",
     start_s=5,end_s=5)
  aqt_functional_event_grid(d,events,outcome="value",
    grid_s=-5:5,max_gap_s=1.1)
}

test_that("functional mixed design validates fish within replicated tanks", {
  grid <- .aqt_longitudinal_fixture()
  prep <- aqt_functional_longitudinal_prepare(grid)
  expect_s3_class(prep,"aqt_functional_longitudinal_frame")
  expect_equal(nrow(prep),8*3*11)
  expect_equal(attr(prep,"aqt_time_grid"),-5:5)
  expect_equal(attr(prep,"aqt_design_audit")$n_tanks,c(4,4))
  expect_equal(length(unique(prep$tank_id)),8)
  expect_equal(length(unique(paste(prep$tank_id,
    prep$fish_unit,sep="\r"))),24)
  expect_true(all(vapply(split(prep$time_index,
    interaction(prep$tank_id,prep$fish_unit,drop=TRUE)),
    function(x)identical(x,0:10),logical(1L))))
})

test_that("functional model rejects unsupported or unequal-interval fish curves", {
  x <- .aqt_longitudinal_fixture()
  x$supported[1L] <- FALSE
  x$value[1L] <- NA_real_
  expect_error(aqt_functional_longitudinal_prepare(x),
               "fully observed finite")
  x <- .aqt_longitudinal_fixture()
  x$time_relative_s[x$time_relative_s==5] <- 5.2
  expect_error(aqt_functional_longitudinal_prepare(x),
               "uniformly spaced")
  x <- .aqt_longitudinal_fixture()
  x <- x[-1L,,drop=FALSE]
  class(x) <- c("aqt_functional_event_grid","data.frame")
  expect_error(aqt_functional_longitudinal_prepare(x),
               "identical complete")
  x <- .aqt_longitudinal_fixture()
  x$treatment[1L] <- "treatment"
  expect_error(aqt_functional_longitudinal_prepare(x),
               "Treatment varies within tank")
  x <- .aqt_longitudinal_fixture(4)
  expect_error(aqt_functional_longitudinal_prepare(x),
               ">=3 independent tanks")
})

test_that("nlme fits nested time-spline with independent residual option", {
  testthat::skip_if_not_installed("nlme")
  prepared <- aqt_functional_longitudinal_prepare(
    .aqt_longitudinal_fixture())
  fit <- aqt_functional_longitudinal_fit(prepared,
    spline_df=3L,residual="independent",method="REML")
  expect_s3_class(fit,"aqt_functional_longitudinal_fit")
  expect_s3_class(fit$model,"lme")
  expect_equal(fit$n_tanks,8)
  expect_equal(fit$n_fish,24)
  expect_identical(fit$backend,"nlme")
  expect_identical(fit$residual_structure,"independent")
  expect_false(fit$causal_identification)
  expect_false(fit$measurement_error_modeled)
  expect_false(fit$coverage_certified)
  expect_equal(length(fit$time_grid),11)
  expect_true(all(is.finite(fit$fixed_effects[,"Value"])))
})

test_that("AR1 residual correlation is explicit and per fish, not per frame cluster", {
  testthat::skip_if_not_installed("nlme")
  prepared <- aqt_functional_longitudinal_prepare(
    .aqt_longitudinal_fixture())
  fit <- aqt_functional_longitudinal_fit(prepared,
    spline_df=3L,residual="ar1",method="ML")
  expect_s3_class(fit$model,"lme")
  expect_identical(fit$residual_structure,"ar1")
  expect_true(!is.null(fit$model$modelStruct$corStruct))
  expect_false(fit$eye_trajectories_native_r_parity_claim)
})

test_that("spline model refuses invalid inputs and overly flexible bases", {
  expect_error(aqt_functional_longitudinal_fit(list()),
               "prepare first")
  prep <- aqt_functional_longitudinal_prepare(
    .aqt_longitudinal_fixture())
  expect_error(aqt_functional_longitudinal_fit(prep,spline_df=7),
               "spline_df")
  expect_error(aqt_functional_longitudinal_fit(prep,
               residual="unsupported"),
               "should be one of")
})
