# Measured planar scale and sampled zone occupancy are not physical
# underwater reconstruction or continuous dwell-time estimation.
.cov100_zone_tracks <- function(three=FALSE) {
 d <- data.frame(session_id="S",camera_id="C",track_id="F",
          time_s=0:3,x=c(0,10,20,30),y=c(0,10,20,30),
          observed=c(TRUE,TRUE,TRUE,FALSE))
 if(three) d$z <- c(0,5,10,NA_real_)
 aqt_tracks(d,units=if(three)"cm" else "px",
               coordinate_system=if(three)"tank" else "image")
}
.cov100_zones <- function() {
 data.frame(zone_id=c("near","far"),xmin=c(-1,15),xmax=c(15,35),
   ymin=c(-1,15),ymax=c(15,35))
}
test_that("planar scaling keeps source pixels and refuses uncalibrated geometry",{
 image <- .cov100_zone_tracks()
 expect_error(aqt_scale_calibrate(image,pixels_per_cm=0),"positive and finite")
 expect_error(aqt_scale_calibrate(image,pixels_per_cm=Inf),"positive and finite")
 expect_error(aqt_scale_calibrate(image,pixels_per_cm=NA_real_),"positive and finite")
 physical <- .cov100_zone_tracks(TRUE)
 expect_error(aqt_scale_calibrate(physical,pixels_per_cm=10),
              "Requires 2D pixel-space")
 out <- aqt_scale_calibrate(image,pixels_per_cm=10)
 expect_equal(out$x[c(1,2,3)],c(0,1,2),tolerance=1e-12)
 expect_equal(out$x_px[c(1,2,3)],c(0,10,20))
 expect_identical(attr(out,"aqt_units"),"cm")
 expect_identical(attr(out,"aqt_calibration")$type,"planar_scale")
})
test_that("sampled occupancy does not invent missing rows or depth",{
 tr <- .cov100_zone_tracks()
 z <- .cov100_zones()
 expect_error(aqt_zone_occupancy(tr,list()),"zones must be a nonempty")
 expect_error(aqt_zone_occupancy(tr,z[0,,drop=FALSE]),"zones must be a nonempty")
 bad <- z;bad$zone_id[2] <- bad$zone_id[1]
 expect_error(aqt_zone_occupancy(tr,bad),"zone_id must be unique")
 bad <- z;bad$xmin[1] <- NA_real_
 expect_error(aqt_zone_occupancy(tr,bad),"Zone bounds must be finite")
 bad <- z;bad$xmax[1] <- bad$xmin[1]
 expect_error(aqt_zone_occupancy(tr,bad),"Zone maxima must exceed")
 bad <- z;bad$zmin <- c(0,0);bad$zmax <- c(10,20)
 expect_error(aqt_zone_occupancy(tr,bad),"Depth bounds require true 3D")
 out <- aqt_zone_occupancy(tr,z)
 expect_equal(out$n_valid,c(3,3))
 expect_equal(out$n_in_zone,c(2,1))
 expect_equal(out$sample_fraction,c(2/3,1/3),tolerance=1e-12)
 three <- .cov100_zone_tracks(TRUE)
 deep <- z
 deep$zmin <- c(-1,1);deep$zmax <- c(6,11)
 three_out <- aqt_zone_occupancy(three,deep)
 expect_equal(three_out$n_valid,c(3,3))
 expect_equal(three_out$n_in_zone,c(2,1))
 bad <- deep;bad$zmax[1] <- bad$zmin[1]
 expect_error(aqt_zone_occupancy(three,bad),"Invalid depth bounds")
 missing <- as.data.frame(tr)
 missing$x[] <- NA_real_
 missing$y[] <- NA_real_
 missing$observed[] <- FALSE
 empty <- aqt_tracks(missing,units="px",coordinate_system="image")
 no_values <- aqt_zone_occupancy(empty,z)
 expect_equal(no_values$n_valid,c(0,0))
 expect_true(all(is.na(no_values$sample_fraction)))
})
