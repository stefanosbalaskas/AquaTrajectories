# Independent synthetic surveyed XYZ points are compared against numerical
# refractive rays. Truth is known by construction, not measured fish landmarks.
.cov100_landmark_stereo <- function() {
 c1 <- aqt_refractive_camera(diag(3),diag(3),c(0,0,0),
         c(0,0,1),c(0,0,1),n_before=1,n_after=1,units="cm")
 c2 <- aqt_refractive_camera(diag(3),diag(3),c(2,0,0),
         c(0,0,1),c(0,0,1),n_before=1,n_after=1,units="cm")
 xyz <- rbind(c(0,.1,5),c(1,-.2,6),c(.5,.3,7),
              c(1.4,.1,8),c(.2,-.3,9))
 a <- cbind(xyz[,1]/xyz[,3],xyz[,2]/xyz[,3])
 b <- cbind((xyz[,1]-2)/xyz[,3],xyz[,2]/xyz[,3])
 list(a=c1,b=c2,pxa=a,pxb=b,xyz=xyz)
}
test_that("refractive stereo landmark benchmark enforces truly paired reference targets",{
 f <- .cov100_landmark_stereo()
 fun <- function(xyz=f$xyz,pa=f$pxa,pb=f$pxb,ids=NULL,...)
   aqt_stereo_landmark_benchmark(f$a,f$b,pa,pb,xyz,
                                 landmark_id=ids,...)
 expect_error(fun(xyz=f$xyz[1:2,,drop=FALSE],
                  pa=f$pxa[1:2,,drop=FALSE],
                  pb=f$pxb[1:2,,drop=FALSE]),
              ">=3 paired image")
 expect_error(fun(pa=f$pxa[1:4,,drop=FALSE]),
              ">=3 paired image")
 expect_error(fun(ids=c("A","A","B","C","D")),
              "unique nonmissing IDs")
 expect_error(fun(ids=rep(NA_character_,5)),
              "unique nonmissing IDs")
 expect_error(fun(ids=c("A","B","C")),
              "unique nonmissing IDs")
 result <- fun()
 expect_s3_class(result,"aqt_stereo_landmark_benchmark")
 expect_equal(result$summary$n_total,5)
 expect_equal(result$summary$n_valid,5)
 expect_equal(result$summary$rmse_3d,0,tolerance=1e-6)
 expect_false(result$calibration_certified)
 expect_true(result$truth_independent_assumed)
 expect_identical(result$units,"cm")
})
test_that("depth-group audit never substitutes reconstructed depth for surveyed depth",{
 f <- .cov100_landmark_stereo()
 benchmark <- aqt_stereo_landmark_benchmark(
     f$a,f$b,f$pxa,f$pxb,f$xyz)
 expect_error(aqt_stereo_depth_audit(list(),c(1,3,5)),
              "Expected aqt_stereo_landmark_benchmark")
 expect_error(aqt_stereo_depth_audit(benchmark,c(4,10)),
              "strictly increasing")
 expect_error(aqt_stereo_depth_audit(benchmark,c(4,4,10)),
              "strictly increasing")
 expect_error(aqt_stereo_depth_audit(benchmark,c(4,NA_real_,10)),
              "strictly increasing")
 expect_error(aqt_stereo_depth_audit(benchmark,c(6,7,8)),
              "encompass all independently measured")
 report <- aqt_stereo_depth_audit(benchmark,c(4,6,8,10))
 expect_equal(sum(report$n_reference),5)
 expect_true(all(report$valid_fraction==1))
 expect_true(all(report$rmse_3d<1e-5))
 expect_false(benchmark$calibration_certified)
 # Independently supplied truth contains an in-range target with failed ray fit.
 perturbed <- f$pxb
 perturbed[1,] <- c(2,1.2)
 failed <- aqt_stereo_landmark_benchmark(f$a,f$b,f$pxa,perturbed,
                      f$xyz,max_separation=.01)
 expect_lt(failed$summary$n_valid,5)
 audit <- aqt_stereo_depth_audit(failed,c(4,6,8,10))
 expect_equal(sum(audit$n_reference),5)
 expect_equal(sum(audit$n_valid),failed$summary$n_valid)
})
