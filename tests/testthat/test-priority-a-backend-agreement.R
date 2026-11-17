# Priority A -- established R modelling backend agreement.
# Exact wrapper/backend equivalence is not external biological validation.
# Fixed model formulas, tank grouping and sample support remain research choices.

test_that("hierarchical event fit matches directly specified nlme::lme", {
  skip_if_not_installed("nlme")
  tanks <- paste0("T",seq_len(12L))
  d <- do.call(rbind,lapply(seq_along(tanks),function(i)
    do.call(rbind,lapply(1:3,function(f)
      data.frame(tank_id=tanks[i],
        treatment=if(i<=6)"control" else "treatment",
        camera_id="TOP",track_id=paste0("fish",f),
        epoch=c("baseline","response"),
        value=c(4+.2*i+.25*f+.3*sin(i+f),
          4+.2*i+.25*f+.3*sin(i+f)+.2*cos(i+f)+
             if(i<=6).15 else .75))))))
  prepared <- aqt_hierarchical_event_prepare(d)
  wrapper <- aqt_hierarchical_event_fit(prepared,method="REML")
  reference <- nlme::lme(
      fixed=value ~ treatment*epoch,
      random=~1 | tank_id/fish_unit,
      data=as.data.frame(prepared),method="REML",
      na.action=stats::na.fail,
      control=nlme::lmeControl(returnObject=FALSE))
  expect_equal(unname(nlme::fixef(wrapper$model)),
               unname(nlme::fixef(reference)),tolerance=1e-10)
  expect_equal(as.numeric(stats::logLik(wrapper$model)),
               as.numeric(stats::logLik(reference)),tolerance=1e-10)
  expect_equal(wrapper$n_tanks,12)
  expect_equal(wrapper$n_fish,36)
  expect_false(wrapper$treatment_causal)
  expect_false(wrapper$measurement_error_modeled)
})

test_that("sparse functional adapter passes identical inputs to fdapace backend", {
  skip_if_not_installed("fdapace")
  set.seed(241)
  base <- seq(0,1,length.out=12)
  d <- do.call(rbind,lapply(seq_len(32L),function(i) {
    obs <- sample(seq_along(base),size=8,replace=FALSE)
    observed <- seq_along(base) %in% obs
    time <- base+seq_along(base)*1e-5*i
    x <- cos(2*pi*time)+.04*i*sin(pi*time)+
         .08*sin((i %% 9)+seq_along(base))
    data.frame(session_id="S",camera_id="TOP",
      track_id=paste0("F",sprintf("%02d",i)),
      time_s=time,x=ifelse(observed,x,NA_real_),
      y=ifelse(observed,2*x,NA_real_),observed=observed)
  }))
  tracks <- aqt_tracks(d,units="cm",coordinate_system="tank")
  input <- aqt_sparse_fpca_input(tracks,coordinate="x",
                                  time_axis="relative",min_points=5)
  expect_equal(length(input$Ly),32L)
  expect_true(input$missingness_explicit)
  expect_true(all(vapply(input$Lt,
    function(t)all(diff(t)>0),logical(1L))))
  set.seed(333)
  wrapped <- aqt_sparse_fpca_fit(input)
  set.seed(333)
  direct <- fdapace::FPCA(input$Ly,input$Lt,
                         optns=list(dataType="Sparse",plot=FALSE))
  expect_equal(wrapped$fit$lambda,direct$lambda,tolerance=1e-8)
  expect_equal(wrapped$fit$mu,direct$mu,tolerance=1e-8)
  expect_equal(wrapped$fit$xiEst,direct$xiEst,tolerance=1e-8)
  expect_identical(wrapped$backend,"fdapace")
  expect_false(wrapped$eyetrajectories_parity_claim)
  audit <- aqt_sparse_fpca_design_audit(input,bins=10L)
  expect_true(all(audit$n_curves>=0 & audit$n_curves<=32))
  expect_equal(audit$curve_fraction,audit$n_curves/32,
               tolerance=1e-12)
})
