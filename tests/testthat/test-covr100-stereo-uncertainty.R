# Independently calibrated pinhole synthetic known-point uncertainty.
# Quantiles are conditional Monte Carlo sensitivity, NOT confidence intervals.
.cov100_mc_data <- function() {
 a <- matrix(c(0,0),ncol=2)
 b <- matrix(c(-.4,0),ncol=2)
 p1 <- cbind(diag(3),c(0,0,0))
 p2 <- cbind(diag(3),c(-2,0,0))
 list(a=a,b=b,p1=p1,p2=p2)
}
test_that("stereo pixel uncertainty rejects invalid stochastic inputs",{
 z <- .cov100_mc_data()
 fun <- function(a=z$a,b=z$b,sigma_px=.1,draws=20,seed=17,level=.95)
   aqt_stereo_pixel_mc(a,b,z$p1,z$p2,sigma_px=sigma_px,
                        draws=draws,seed=seed,level=level)
 expect_error(fun(a=matrix(1:4,ncol=4)),"corresponding n-by-2")
 expect_error(fun(b=matrix(1:4,ncol=2)),"corresponding n-by-2")
 expect_error(fun(sigma_px=-1),"sigma_px must")
 expect_error(fun(sigma_px=c(1,2,3)),"sigma_px must")
 expect_error(fun(sigma_px=Inf),"sigma_px must")
 expect_error(fun(draws=19),"draws must")
 expect_error(fun(draws=20.5),"draws must")
 expect_error(fun(seed=-1),"seed must")
 expect_error(fun(seed=2^31),"seed must")
 expect_error(fun(level=0),"level must")
 expect_error(fun(level=1),"level must")
 expect_error(fun(level=NA_real_),"level must")
 set.seed(104);prior <- .Random.seed
 exact <- fun(sigma_px=0,draws=20)
 expect_identical(.Random.seed,prior)
 expect_equal(exact$x,0,tolerance=1e-10)
 expect_equal(exact$y,0,tolerance=1e-10)
 expect_equal(exact$z,5,tolerance=1e-8)
 expect_equal(exact$sd_x,0,tolerance=1e-10)
 expect_equal(exact$valid_fraction,1)
 expect_false("confidence_interval" %in% names(exact))
 noisy <- fun(sigma_px=c(.01,.03),draws=40)
 expect_equal(noisy$n_valid_draws,40)
 expect_true(all(is.finite(noisy[,c("sd_x","sd_y","sd_z")])))
 expect_identical(.Random.seed,prior)
 expect_equal(attr(noisy,"aqt_conditional_model")$sigma_px,c(.01,.03))
 empty <- fun(a=matrix(numeric(0),ncol=2),b=matrix(numeric(0),ncol=2))
 expect_equal(nrow(empty),0)
})
test_that("stereo uncertainty propagation refuses invalid original view provenance",{
 z <- .cov100_mc_data()
 trA <- aqt_tracks(data.frame(session_id="S",camera_id="A",
       track_id="a",time_s=0,x=0,y=0))
 trB <- aqt_tracks(data.frame(session_id="S",camera_id="B",
       track_id="b",time_s=0,x=-.4,y=0))
 rig <- aqt_rig_new(list(A=z$p1,B=z$p2),optical_path="air_only")
 match <- data.frame(session_id="S",id_a="a",id_b="b",
    time_a_s=0,time_b_s=0,fish_id="fish")
 out <- aqt_reconstruct_3d(trA,trB,match,rig)
 expect_error(aqt_reconstruction_pixel_uncertainty(trA,trA,trB),
              "Expected aqt_reconstruct_3d")
 wrongB <- as.data.frame(trB);wrongB$camera_id <- "C"
 expect_error(aqt_reconstruction_pixel_uncertainty(out,trA,aqt_tracks(wrongB)),
              "Camera data do not match")
 changed <- as.data.frame(trB);changed$track_id <- "incorrect"
 expect_error(aqt_reconstruction_pixel_uncertainty(out,trA,aqt_tracks(changed)),
              "Original camera observations are missing")
 uncertain <- aqt_reconstruction_pixel_uncertainty(out,trA,trB,
       sigma_px=0,draws=20,seed=22)
 expect_s3_class(uncertain,"aqt_tracks")
 expect_equal(uncertain$valid_fraction,1)
 expect_equal(uncertain$sd_z,0,tolerance=1e-8)
 expect_false(attr(uncertain,"aqt_rig")$calibration_qualified)
})
