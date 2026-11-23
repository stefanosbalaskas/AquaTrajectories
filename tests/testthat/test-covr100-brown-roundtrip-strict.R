# Numerical Brown-model inverse requires an explicit forward roundtrip
# residual bound; an over-tight bound must not invent valid corrections.
test_that("Brown undistortion refuses a converged inverse failing strict pixel roundtrip",{
 lens <- aqt_brown_camera(diag(3),k1=.08,k2=.03,
      p1=.001,p2=-.002,max_normalized_radius=2)
 p <- matrix(c(.67,.41),nrow=1)
 loose <- aqt_brown_undistort_pixels(lens,p,
       tolerance_norm=1e-8,max_roundtrip_px=.01)
 expect_true(loose$valid[1L])
 strict <- aqt_brown_undistort_pixels(lens,p,
       tolerance_norm=1e-8,max_roundtrip_px=1e-18)
 expect_false(strict$valid[1L])
 expect_true(is.na(strict$x_px[1L]))
 expect_false(lens$calibration_certified)
})
