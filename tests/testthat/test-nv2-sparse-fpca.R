# Sparse functional estimation under explicit, reproducible synthetic designs.
# The external fdapace backend is the reference implementation, not a
# statistically independent estimator. Design/support tests are independent.

test_that("NV2_SPARSE_FPCA: irregular rank-one design, coverage oracle and failures", {
  skip_if_not_installed("fdapace")
  set.seed(601)
  t<-seq(0,1,length.out=25)
  d<-do.call(rbind,lapply(1:48,function(i){
    observed<-((seq_along(t)+i*3) %% 5L!=0L)
    curve<-1.5+.4*t+(.3+0.12*sin(i))*sin(2*pi*t)+
      stats::rnorm(length(t),0,.025)
    data.frame(session_id="S",camera_id="C",
      track_id=sprintf("F%03d",i),time_s=t,
      x=ifelse(observed,curve,NA_real_),
      y=ifelse(observed,2*curve,NA_real_),observed=observed)
  }))
  tr<-aqt_tracks(d,units="cm",coordinate_system="tank")
  input<-aqt_sparse_fpca_input(tr,coordinate="x",
                              time_axis="relative",min_points=12)
  expect_equal(length(input$Ly),48L)
  expect_true(all(input$scope$n_observed<input$scope$n_total))
  audit<-aqt_sparse_fpca_design_audit(input,bins=15L)
  limits<-seq(min(unlist(input$Lt)),max(unlist(input$Lt)),length.out=16)
  independent<-vapply(1:15,function(bin)
    sum(vapply(input$Lt,function(tt)
      any(findInterval(tt,limits,rightmost.closed=TRUE,
                       all.inside=TRUE)==bin),logical(1L))),
      numeric(1L))
  expect_equal(audit$n_curves,independent)
  expect_true(all(audit$curve_fraction>=0 & audit$curve_fraction<=1))
  expect_equal(sum(input$scope$n_observed),
               sum(vapply(input$Ly,length,integer(1L))))
  # Separate calls to the maintained method, with the same frozen input/seed.
  set.seed(703)
  wrapped<-aqt_sparse_fpca_fit(input)
  set.seed(703)
  direct<-fdapace::FPCA(input$Ly,input$Lt,
               optns=list(dataType="Sparse",plot=FALSE))
  expect_equal(wrapped$fit$lambda,direct$lambda,tolerance=1e-8)
  expect_equal(wrapped$fit$mu,direct$mu,tolerance=1e-8)
  expect_equal(wrapped$fit$xiEst,direct$xiEst,tolerance=1e-8)
  expect_true(all(is.finite(wrapped$fit$lambda)))
  expect_true(all(wrapped$fit$lambda>=-1e-8))
  expect_equal(length(wrapped$input_audit$n_curves),10L)
  expect_false(wrapped$eyetrajectories_parity_claim)
  shifted<-d;shifted$time_s<-100+2*shifted$time_s
  rel<-aqt_sparse_fpca_input(
    aqt_tracks(shifted,"cm","tank"),time_axis="relative",
    min_points=12)
  expect_equal(input$Ly,rel$Ly,tolerance=1e-12)
  expect_equal(input$Lt,rel$Lt,tolerance=1e-12)
  fail<-d
  ix<-which(fail$track_id=="F001")
  fail$x[ix[-(1:2)]]<-NA_real_
  fail$y[ix[-(1:2)]]<-NA_real_
  fail$observed[ix[-(1:2)]]<-FALSE
  expect_error(aqt_sparse_fpca_input(
    aqt_tracks(fail,"cm","tank"),min_points=12),
    "Insufficient observed")
  expect_error(aqt_sparse_fpca_design_audit(input,bins=4),
               "between 5 and 100")
  expect_error(aqt_sparse_fpca_fit(input,optns=list(dataType="Dense")),
               "fixed")
})

test_that("NV2_SPARSE_FPCA: low temporal support is explicitly detectable", {
  tt<-seq(0,1,length.out=25)
  d<-do.call(rbind,lapply(1:10,function(i){
    observed<-if(i<=8)seq_along(tt)<=6L else seq_along(tt)>=20L
    data.frame(session_id="S",camera_id="C",track_id=paste0("F",i),
      time_s=tt,x=ifelse(observed,sin(tt+i/2),NA_real_),
      y=ifelse(observed,cos(tt+i/2),NA_real_),
      observed=observed)
  }))
  tracks<-aqt_tracks(d,units="cm",coordinate_system="tank")
  input<-aqt_sparse_fpca_input(tracks,min_points=5)
  audit<-aqt_sparse_fpca_design_audit(input,bins=10)
  expect_true(any(audit$n_curves==0L))
  expect_true(any(audit$low_coverage))
  expect_true(any(audit$n_curves>0L))
  expect_equal(nrow(audit),10L)
  # Unobserved support must NOT be converted into interpolated Ly.
  expect_equal(sum(vapply(input$Ly,length,integer(1L))),
               sum(tracks$observed))
})
