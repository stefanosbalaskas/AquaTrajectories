# An idealized known-XYZ translation-only fit tests numerical contracts,
# not real glass-port calibration. Source points are synthetic and declared.
.cov100_refine_fixture <- function() {
 camera <- aqt_flatport_camera(K=diag(3),R_c2w=diag(3),
    center=c(0,0,-1),glass_front_point=c(0,0,0),
    glass_normal=c(0,0,1),glass_thickness=.1,
    n_first=1,n_glass=1,n_water=1,units="cm")
 z <- seq(1,3,length.out=10)
 xyz <- cbind(x=seq(.1,.5,length.out=10),
              y=sin(seq_len(10))*.2,z=z)
 pixel <- cbind(xyz[,1]/(z+1),xyz[,2]/(z+1))
 list(camera=camera,xyz=xyz,pixels=pixel)
}
test_that("translation-only flatport refinement enforces independently separate physical targets",{
 f <- .cov100_refine_fixture()
 fun <- function(camera=f$camera,pixels=f$pixels,xyz=f$xyz,
       training=1:8,holdout=9:10,...)
   aqt_flatport_refine_center(camera,pixels,xyz,training,
                             holdout,...)
 expect_error(fun(camera=list()),"two-interface flatport")
 expect_error(fun(pixels=f$pixels[1:7,,drop=FALSE],
                  xyz=f$xyz[1:7,,drop=FALSE],training=1:6,holdout=6:7),
              "at least eight paired")
 expect_error(fun(training=1:5),"at least 6")
 expect_error(fun(holdout=9),"at least 2")
 expect_error(fun(training=1:8,holdout=c(8,9)),"must be disjoint")
 bad <- f$xyz;bad[9,] <- bad[1,]
 expect_error(fun(xyz=bad),"coordinates must not repeat")
 bad <- f$xyz;bad[1:8,3] <- 1
 expect_error(fun(xyz=bad),"variation in 3D depth")
 bad <- f$xyz;bad[9,3] <- .05
 expect_error(fun(xyz=bad),"beyond the glass")
 expect_error(fun(max_center_shift=0),"positive physical bound")
 expect_error(fun(max_center_shift=Inf),"positive physical bound")
 expect_error(fun(max_center_shift=NA_real_),"positive physical bound")
 expect_error(fun(maxit=19),"integer >=20")
 expect_error(fun(maxit=20.5),"integer >=20")
 expect_error(fun(maxit=Inf),"integer >=20")
 bad <- f$pixels;bad[,] <- 1e7
 expect_error(fun(pixels=bad),"does not see all reviewed landmarks")
})
test_that("synthetic translation-only optimizer retains heldout raw XYZ and fixed optics",{
 f <- .cov100_refine_fixture()
 before <- serialize(f$xyz,NULL)
 result <- aqt_flatport_refine_center(f$camera,f$pixels,f$xyz,
                   training=1:8,holdout=9:10,max_center_shift=.1,maxit=100)
 expect_identical(serialize(f$xyz,NULL),before)
 expect_identical(result$calibration_parameters,"translation_only")
 expect_equal(result$training_n,8L)
 expect_equal(result$holdout_n,2L)
 expect_true(result$train_rmse_before<1e-8)
 expect_true(result$holdout_rmse_before<1e-8)
 expect_true(result$holdout_rmse_after<1e-5)
 expect_true(max(abs(result$center_adjustment))<=.1)
 expect_identical(result$camera$K,f$camera$K)
 expect_equal(result$camera$glass_thickness,f$camera$glass_thickness)
 expect_false(result$calibration_certified)
 expect_true(result$heldout_independence_requires_external_design)
})
