# An independently specified, known latent functional process.
# This is estimator recovery under a favourable synthetic MAR sampling
# design, not coverage or performance under MNAR/occlusion in real tanks.
test_that("NV2_SPARSE_POPULATION: independent one-factor mean/covariance recovery",{
  skip_if_not_installed("fdapace")
  set.seed(20261121)
  true_mu<-function(t) 1+.3*t+.25*sin(2*pi*t)
  true_phi<-function(t) sqrt(2)*cos(pi*t)
  points<-seq(0,1,length.out=31)
  fish<-do.call(rbind,lapply(seq_len(100L),function(i){
    mask<-sort(sample(seq_along(points),size=12L,replace=FALSE))
    a<-rnorm(1L,sd=.85)
    values<-true_mu(points)+a*true_phi(points)+
      rnorm(length(points),sd=.05)
    seen<-seq_along(points)%in%mask
    data.frame(session_id="S",camera_id="CAM",track_id=sprintf("fish%03d",i),
      time_s=points,
      x=ifelse(seen,values,NA_real_),
      y=ifelse(seen,values+.1,NA_real_),observed=seen)
  }))
  tr<-aqt_tracks(fish,units="cm",coordinate_system="tank")
  input<-aqt_sparse_fpca_input(tr,coordinate="x",
                         time_axis="relative",min_points=10L)
  set.seed(7442)
  fit<-aqt_sparse_fpca_fit(input)
  f<-fit$fit
  expect_true(is.numeric(f$mu)&&length(f$mu)>=10)
  expect_true(is.numeric(f$workGrid))
  expect_true(is.matrix(f$phi)&&ncol(f$phi)>=1)
  expect_true(all(is.finite(f$mu)))
  truth_mean<-true_mu(f$workGrid)
  mean_RMSE<-sqrt(mean((f$mu-truth_mean)^2))
  orientation_free_correlation<-abs(stats::cor(
      f$phi[,1],true_phi(f$workGrid)))
  # Disclose tolerances: designed to be robust to reasonable smoothing
  # variability while detecting mean/eigensurface structural mistakes.
  expect_lt(mean_RMSE,.4)
  expect_gt(orientation_free_correlation,.7)
  expect_true(all(is.finite(f$lambda)))
  expect_true(all(f$lambda>=-1e-8))
  expect_identical(fit$backend,"fdapace")
  expect_false(fit$eyetrajectories_parity_claim)
})
