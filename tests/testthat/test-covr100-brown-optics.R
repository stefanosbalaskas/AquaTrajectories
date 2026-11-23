# Ideal Brown perspective correction is a model-conditional pixel
# transformation, not fitted intrinsic calibration for a real action camera.
.cov100_brown <- function(k1=0,rad=2) {
 aqt_brown_camera(diag(3),k1=k1,max_normalized_radius=rad)
}
test_that("Brown distortion explicitly handles zero rows, missing pixels and FOV limits",{
 model<-.cov100_brown(k1=.01,rad=1)
 expect_error(aqt_brown_distort_pixels(list(),matrix(c(0,0),ncol=2)),
              "Expected aqt_brown_camera")
 empty<-aqt_brown_distort_pixels(model,matrix(numeric(0),ncol=2))
 expect_equal(nrow(empty),0L)
 all_missing<-aqt_brown_distort_pixels(model,
                    matrix(c(NA_real_,NA_real_),ncol=2))
 expect_equal(all_missing$valid,FALSE)
 expect_true(is.na(all_missing$x_px))
 outside<-aqt_brown_distort_pixels(model,matrix(c(8,8),ncol=2))
 expect_false(outside$valid)
 mixed<-aqt_brown_distort_pixels(model,
                    matrix(c(0,0,NA_real_,NA_real_,8,8),
                           ncol=2,byrow=TRUE))
 expect_identical(mixed$valid,c(TRUE,FALSE,FALSE))
 expect_equal(mixed$x_px[1],0)
 expect_error(aqt_brown_distort_pixels(model,
                 matrix(c(Inf,0),ncol=2)),"without infinities")
})
test_that("Brown inverse retains unknowns and rejects nonconvergent extreme optics",{
 model<-.cov100_brown()
 expect_error(aqt_brown_undistort_pixels(list(),matrix(c(0,0),ncol=2)),
              "Expected aqt_brown_camera")
 expect_error(aqt_brown_undistort_pixels(model,
              matrix(c(0,0),ncol=2),max_iter=0),"max_iter must")
 expect_error(aqt_brown_undistort_pixels(model,
              matrix(c(0,0),ncol=2),max_iter=201),"max_iter must")
 expect_error(aqt_brown_undistort_pixels(model,
              matrix(c(0,0),ncol=2),tolerance_norm=0),
              "Undistortion thresholds")
 expect_error(aqt_brown_undistort_pixels(model,
              matrix(c(0,0),ncol=2),max_roundtrip_px=Inf),
              "Undistortion thresholds")
 empty<-aqt_brown_undistort_pixels(model,matrix(numeric(0),ncol=2))
 expect_equal(nrow(empty),0L)
 missing<-aqt_brown_undistort_pixels(model,
              matrix(c(NA_real_,NA_real_),ncol=2))
 expect_false(missing$valid)
 outside<-aqt_brown_undistort_pixels(.cov100_brown(rad=1),
              matrix(c(100,0),ncol=2))
 expect_false(outside$valid)
 radial_zero<-aqt_brown_undistort_pixels(.cov100_brown(k1=-1,rad=2),
              matrix(c(1,0),ncol=2))
 expect_false(radial_zero$valid)
 valid<-aqt_brown_undistort_pixels(model,matrix(c(.1,.2),ncol=2))
 expect_true(valid$valid)
 expect_equal(valid$x_px,.1,tolerance=1e-12)
 expect_equal(valid$y_px,.2,tolerance=1e-12)
})
test_that("lens tracks and two-interface rays preserve original detector pixels",{
 camera<-aqt_flatport_camera(diag(3),diag(3),c(0,0,-1),
   c(0,0,0),c(0,0,1),glass_thickness=.1,n_first=1,
   n_glass=1,n_water=1,units="cm")
 lens<-.cov100_brown()
 pixel<-matrix(c(0,0,.1,.2),ncol=2,byrow=TRUE)
 expect_error(aqt_flatport_rays_distorted(list(),lens,pixel),
              "Expected a flatport camera")
 expect_error(aqt_flatport_rays_distorted(camera,list(),pixel),
              "Expected a flatport camera")
 wrong<-aqt_brown_camera(diag(c(2,2,1)))
 expect_error(aqt_flatport_rays_distorted(camera,wrong,pixel),
              "identical intrinsics")
 rays<-aqt_flatport_rays_distorted(camera,lens,pixel)
 expect_equal(nrow(rays),2L)
 expect_true(all(rays$lens_undistortion_valid))
 expect_false(attr(rays,"aqt_lens_calibration_certified"))
 empty<-aqt_flatport_rays_distorted(camera,lens,
              matrix(numeric(0),ncol=2))
 expect_equal(nrow(empty),0L)
 d<-data.frame(session_id="S",camera_id="TOP",track_id="F",
              time_s=c(0,1),x=c(0,.1),y=c(0,.2))
 tr<-aqt_tracks(d)
 expect_error(aqt_brown_undistort_tracks(tr,list()),
              "Expected aqt_brown_camera")
 physical<-aqt_tracks(transform(d,z=1),units="cm",
                      coordinate_system="tank")
 expect_error(aqt_brown_undistort_tracks(physical,lens),
              "requires 2D image pixel tracks")
 corrected<-aqt_brown_undistort_tracks(tr,lens)
 expect_true(all(corrected$lens_undistortion_valid))
 expect_equal(corrected$distorted_x_px,d$x)
 expect_equal(corrected$x,d$x,tolerance=1e-12)
 expect_false(attr(corrected,"aqt_lens_calibration_certified"))
 expect_error(aqt_brown_undistort_tracks(corrected,lens),
              "refuse double correction")
})
