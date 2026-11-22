# Explicit ideal one-interface optics are NOT validated glass-port
# underwater calibration. All rays/landmarks below are synthetic.
.cov100_ref_camera <- function(center=c(0,0,0),units="cm",
                              n_before=1,n_after=1.333) {
 aqt_refractive_camera(K=diag(3),R_c2w=diag(3),center=center,
    plane_point=c(0,0,1),plane_normal=c(0,0,1),
    units=units,n_before=n_before,n_after=n_after)
}
test_that("single-interface refractive camera refuses uncalibrated parameters",{
 good <- .cov100_ref_camera()
 expect_s3_class(good,"aqt_refraction_camera")
 expect_false(good$calibration_validated)
 expect_error(aqt_refractive_camera(diag(2),diag(3),c(0,0,0),
                  c(0,0,1),c(0,0,1)),"K must be a valid")
 k <- diag(3);k[3,1] <- 1
 expect_error(aqt_refractive_camera(k,diag(3),c(0,0,0),
                  c(0,0,1),c(0,0,1)),"K must be a valid")
 badr <- diag(3);badr[1,1] <- 0
 expect_error(aqt_refractive_camera(diag(3),badr,c(0,0,0),
                  c(0,0,1),c(0,0,1)),"proper orthonormal")
 expect_error(aqt_refractive_camera(diag(3),diag(3),c(0,0,0),
                  c(0,0,-1),c(0,0,1)),"Camera must be in front")
 expect_error(aqt_refractive_camera(diag(3),diag(3),c(0,0,0),
                  c(0,0,1),c(0,0,0)),"plane_normal must")
 expect_error(.cov100_ref_camera(n_after=0),"Refractive indices")
 expect_error(.cov100_ref_camera(units="px"),"World units")
})
test_that("refractive rays retain validity flags for nonphysical pixels",{
 cam <- .cov100_ref_camera()
 expect_error(aqt_refractive_rays(list(),matrix(c(0,0),ncol=2)),
              "Expected an ideal single-interface")
 expect_error(aqt_refractive_rays(cam,matrix(1:3,ncol=3)),
              "pixels must be finite")
 expect_error(aqt_refractive_rays(cam,matrix(c(Inf,0),ncol=2)),
              "pixels must be finite")
 empty <- aqt_refractive_rays(cam,matrix(numeric(0),ncol=2))
 expect_equal(nrow(empty),0)
 normal <- aqt_refractive_rays(cam,matrix(c(0,0),ncol=2))
 expect_true(normal$valid)
 expect_equal(normal$origin_z,1,tolerance=1e-12)
 expect_equal(normal$dir_z,1,tolerance=1e-12)
 expect_identical(attr(normal,"aqt_units"),"cm")
 badray <- aqt_refractive_rays(cam,matrix(c(0,1e7),ncol=2))
 expect_true(nrow(badray)==1L)
 # Transition from high to low index at a grazing angle can reflect totally.
 tir <- .cov100_ref_camera(n_before=1.5,n_after=1)
 reflected <- aqt_refractive_rays(tir,matrix(c(100,0),ncol=2))
 expect_false(reflected$valid)
})
test_that("underwater ray triangulation reports failed geometry and unit mismatch",{
 a <- .cov100_ref_camera()
 b <- .cov100_ref_camera(center=c(2,0,0))
 p <- matrix(c(0,0),ncol=2)
 expect_error(aqt_refractive_triangulate(a,b,p,rbind(p,p)),
              "same number of paired points")
 expect_error(aqt_refractive_triangulate(a,.cov100_ref_camera(
              center=c(2,0,0),units="m"),p,p),"common world units")
 expect_error(aqt_refractive_triangulate(a,b,p,p,max_separation=-1),
              "max_separation must")
 equal_cam <- aqt_refractive_triangulate(a,a,p,p)
 expect_false(equal_cam$valid)
 expect_true(is.na(equal_cam$x))
 empty <- aqt_refractive_triangulate(a,b,
             matrix(numeric(0),ncol=2),
             matrix(numeric(0),ncol=2))
 expect_equal(nrow(empty),0L)
 expect_identical(attr(empty,"aqt_units"),"cm")
})
test_that("independent landmarks are source-provided, not fitted truth",{
 cam <- .cov100_ref_camera()
 pixel <- matrix(c(0,0),ncol=2)
 expect_error(aqt_refractive_landmark_qc(cam,pixel,
               matrix(c(1,2,3,4,5,6),ncol=3,byrow=TRUE)),
               "Landmarks and source pixels must be paired")
 q <- aqt_refractive_landmark_qc(cam,pixel,
            matrix(c(0,0,5),ncol=3))
 expect_equal(q$n_valid,1L)
 expect_equal(q$rmse,0,tolerance=1e-12)
 expect_false(q$calibration_certified)
 behind <- aqt_refractive_landmark_qc(cam,pixel,
            matrix(c(0,0,0),ncol=3))
 expect_equal(behind$n_valid,0L)
 expect_true(is.na(behind$rmse))
})
