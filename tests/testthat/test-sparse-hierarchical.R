test_that("sparse functional input preserves observed irregular time points", {
  d <- do.call(rbind,lapply(1:6,function(i) {
    time <- c(0,.3,1,2,4,6)
    observed <- c(TRUE,TRUE,FALSE,TRUE,TRUE,TRUE)
    data.frame(session_id="S",camera_id="TOP",
      track_id=paste0("F",i),time_s=time,
      x=ifelse(observed,i*time,NA_real_),
      y=ifelse(observed,i*time^2,NA_real_),
      observed=observed)
  }))
  tr <- aqt_tracks(d,units="cm",coordinate_system="tank")
  inputs <- aqt_sparse_fpca_input(tr,coordinate="x",
                                 time_axis="relative")
  expect_s3_class(inputs,"aqt_sparse_fpca_input")
  expect_equal(length(inputs$Ly),6)
  expect_true(all(vapply(inputs$Ly,length,integer(1L))==5L))
  expect_true(all(vapply(inputs$Lt,length,integer(1L))==5L))
  expect_equal(inputs$Lt[[1L]],c(0,.3/6,2/6,4/6,1))
  expect_true(all(inputs$scope$observed_fraction==5/6))
  audit <- aqt_sparse_fpca_design_audit(inputs,bins=6)
  expect_equal(nrow(audit),6)
  expect_true(all(audit$n_curves<=6))
  expect_true(all(audit$curve_fraction<=1))
  expect_true(all(audit$n_total_curves==6))
  absolute <- aqt_sparse_fpca_input(tr,coordinate="y",
                                   time_axis="absolute")
  expect_equal(absolute$Lt[[1L]],c(0,.3,2,4,6))
  expect_error(aqt_sparse_fpca_input(tr,coordinate="z"),"available")
})

test_that("sparse FPCA rejects undersupported individual observations", {
  d <- do.call(rbind,lapply(1:6,function(i) {
    data.frame(session_id="S",camera_id="TOP",
      track_id=paste0("F",i),time_s=0:4,
      x=0:4,y=0)
  }))
  d$x[d$track_id=="F1" & d$time_s %in% c(1,2,3)] <- NA_real_
  d$y[d$track_id=="F1" & d$time_s %in% c(1,2,3)] <- NA_real_
  tr <- aqt_tracks(d)
  expect_error(aqt_sparse_fpca_input(tr,min_points=3),
               "Insufficient observed")
  expect_error(aqt_sparse_fpca_input(tr,min_points=2),
               "min_points")
})

test_that("hierarchical design distinguishes independent tanks from fish", {
  tanks <- paste0("T",1:6)
  d <- do.call(rbind,lapply(seq_along(tanks),function(i) {
    do.call(rbind,lapply(1:3,function(f) {
      data.frame(tank_id=tanks[i],
        treatment=if (i<=3) "control" else "treatment",
        camera_id="TOP",track_id=paste0("F",f),
        epoch=c("baseline","response"),
        value=c(2+i/3+f/10,
                3+i/3+f/10+if (i>3) .8 else 0))
    }))
  }))
  frame <- aqt_hierarchical_event_prepare(d)
  expect_s3_class(frame,"aqt_hierarchical_event_frame")
  expect_equal(length(unique(frame$tank_id)),6)
  expect_equal(attr(frame,"aqt_design_audit")$n_tanks,c(3,3))
  expect_equal(nrow(frame),36)
  expect_equal(nlevels(frame$fish_unit),3)
  duplicate <- rbind(d,d[1,,drop=FALSE])
  expect_error(aqt_hierarchical_event_prepare(duplicate),"Duplicate")
  missing <- d[-1L,,drop=FALSE]
  expect_error(aqt_hierarchical_event_prepare(missing),
               "both observed")
  switching <- d
  switching$treatment[1] <- "treatment"
  expect_error(aqt_hierarchical_event_prepare(switching),
               "varies within tank")
})

test_that("optional nlme hierarchy fits the tank/fish nested model", {
  testthat::skip_if_not_installed("nlme")
  tanks <- paste0("T",1:12)
  data <- do.call(rbind,lapply(seq_along(tanks),function(i) {
    do.call(rbind,lapply(1:3,function(j) {
      data.frame(tank_id=tanks[i],
        treatment=if (i<=6) "control" else "treatment",
        camera_id="TOP",track_id=paste0("F",j),
        epoch=c("baseline","response"),
        value=c(5+sin(i)/3+j/4,
                5+sin(i)/3+j/4+cos(i)/7+if (i>6) 1.2 else .2))
    }))
  }))
  frame <- aqt_hierarchical_event_prepare(data)
  fitted <- aqt_hierarchical_event_fit(frame,method="REML")
  expect_s3_class(fitted$model,"lme")
  expect_equal(fitted$n_tanks,12)
  expect_equal(fitted$n_fish,36)
  expect_false(fitted$treatment_causal)
  expect_false(fitted$measurement_error_modeled)
})

test_that("sparse adapter rejects unqualified EyeTrajectories shortcuts", {
  expect_error(aqt_sparse_fpca_fit(list()),"aqt_sparse_fpca_input")
})
