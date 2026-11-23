# Exact Snell-law fault outcomes for an idealized two-surface slab;
# no claim that a physical tank's glass or lens was calibrated.
.cov100_flat_optic <- function(n_first=1,n_glass=1.5,n_water=1.333) {
 aqt_flatport_camera(K=diag(3),R_c2w=diag(3),
     center=c(0,0,-1),glass_front_point=c(0,0,0),
     glass_normal=c(0,0,1),glass_thickness=.1,
     n_first=n_first,n_glass=n_glass,n_water=n_water,units="cm")
}
test_that("two-interface optics reject invalid physical medium declarations",{
 expect_error(aqt_flatport_camera(diag(3),diag(3),c(0,0,-1),
       c(0,0,0),c(0,0,1),glass_thickness=0),"glass_thickness must")
 expect_error(aqt_flatport_camera(diag(3),diag(3),c(0,0,-1),
       c(0,0,0),c(0,0,1),glass_thickness=Inf),"glass_thickness must")
 expect_error(aqt_flatport_camera(diag(3),diag(3),c(0,0,-1),
       c(0,0,0),c(0,0,1),glass_thickness=.1,n_water=0),"n_water must")
 expect_error(aqt_flatport_camera(diag(3),diag(3),c(0,0,-1),
       c(0,0,0),c(0,0,1),glass_thickness=.1,n_water=NA_real_),"n_water must")
 expect_error(aqt_flatport_rays(list(),matrix(c(0,0),ncol=2)),
              "Expected a two-interface")
 bad <- .cov100_flat_optic();bad$model <- "one-interface"
 expect_error(aqt_flatport_rays(bad,matrix(c(0,0),ncol=2)),
              "Expected a two-interface")
})
test_that("two-interface tracing propagates absent rows and TIR at either surface",{
 camera <- .cov100_flat_optic()
 zero <- aqt_flatport_rays(camera,matrix(numeric(0),ncol=2))
 expect_equal(nrow(zero),0)
 direct <- aqt_flatport_rays(camera,matrix(c(0,0),ncol=2))
 expect_true(direct$valid)
 expect_equal(direct$origin_z,.1,tolerance=1e-12)
 expect_equal(direct$dir_z,1,tolerance=1e-12)
 expect_false(camera$calibration_validated)
 # First transition 1.5->1: a sufficiently oblique ray reflects.
 front_reflect <- .cov100_flat_optic(n_first=1.5,n_glass=1,n_water=1)
 first <- aqt_flatport_rays(front_reflect,
                  matrix(c(10,0),ncol=2))
 expect_false(first$valid)
 expect_true(is.na(first$origin_x))
 # Second transition 1.5->1, with no bend at first face, reflects.
 back_reflect <- .cov100_flat_optic(n_first=1.5,n_glass=1.5,n_water=1)
 second <- aqt_flatport_rays(back_reflect,
                    matrix(c(10,0),ncol=2))
 expect_false(second$valid)
 expect_true(is.na(second$dir_z))
 mixed <- aqt_flatport_rays(back_reflect,
                   matrix(c(0,0,10,0),ncol=2,byrow=TRUE))
 expect_identical(mixed$valid,c(TRUE,FALSE))
 expect_identical(attr(mixed,"aqt_units"),"cm")
})
