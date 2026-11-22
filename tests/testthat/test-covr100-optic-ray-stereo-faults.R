# Analytical optics and stereo Monte Carlo tests use exactly known
# synthetic pinhole geometry. They do not infer real underwater calibration.
.cov100_ray_camera <- function(R=diag(3),center=c(0,0,-1)) {
 aqt_refractive_camera(diag(3),R,center,
   plane_point=c(0,0,1),plane_normal=c(0,0,1),
   n_before=1,n_after=1,units="cm")
}
test_that("refractive physical-coordinate validators reject nonfinite survey points",{
 xyz <- aquaTrajectories:::.aqt_ref_xyz
 expect_error(xyz(matrix(c(0,0,Inf),nrow=1),"survey"),
              "survey must be a finite numeric n-by-3")
 expect_error(aqt_refractive_camera(diag(3),diag(3),
                 center=c(0,0,NA_real_),plane_point=c(0,0,1),
                 plane_normal=c(0,0,1)),
              "center and plane_point must be finite")
})
test_that("backwards and numerically nonintersecting refractive rays remain invalid",{
 behind <- .cov100_ray_camera(R=diag(c(1,-1,-1)))
 rays <- aqt_refractive_rays(behind,matrix(c(0,0),nrow=1))
 expect_false(rays$valid)
 expect_true(all(is.na(rays[1,c("origin_x","dir_z")])))
 bad <- aqt_refractive_triangulate(behind,.cov100_ray_camera(),
      matrix(c(0,0),nrow=1),matrix(c(0,0),nrow=1))
 expect_false(bad$valid)
 expect_true(is.na(bad$x))
 qc <- aqt_refractive_landmark_qc(behind,matrix(c(0,0),nrow=1),
                      matrix(c(0,0,5),nrow=1))
 expect_equal(qc$n_valid,0L)
 expect_true(is.na(qc$rmse))
 # Incidence remains positive while plane distance / cos(theta) overflows:
 # finite but physically non-intersecting rays must not enter reconstruction.
 far <- .cov100_ray_camera(center=c(0,0,-1e308))
 ray <- aqt_refractive_rays(far,matrix(c(1e11,0),nrow=1))
 expect_false(ray$valid)
})
test_that("stereo pixel Monte Carlo keeps exact failures and restores absent RNG",{
 P <- cbind(diag(3),c(0,0,0))
 xy <- matrix(c(0,0),nrow=1)
 expect_error(aqt_stereo_pixel_mc(matrix(0,50001,2),
               matrix(0,50001,2),P,P,draws=20),
              "Monte Carlo sample cap exceeded")
 had <- exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE)
 if(had) old <- get(".Random.seed",envir=.GlobalEnv)
 on.exit({
  if(had) assign(".Random.seed",old,envir=.GlobalEnv)
  else if(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
     rm(".Random.seed",envir=.GlobalEnv)
 },add=TRUE)
 if(had) rm(".Random.seed",envir=.GlobalEnv)
 out <- aqt_stereo_pixel_mc(xy,xy,P,P,sigma_px=0,
                           draws=20,seed=45)
 expect_false(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
 expect_equal(out$n_valid_draws,0L)
 expect_equal(out$valid_fraction,0,tolerance=1e-12)
 expect_true(is.na(out$sd_x))
 expect_true(is.na(out$lower_z))
 expect_false(is.null(attr(out,"aqt_conditional_model")))
});
