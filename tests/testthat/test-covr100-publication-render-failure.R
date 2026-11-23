# Source-bound research figure helpers cannot silently manufacture data.
.cov100_pub_minimal <- function() list(
 provenance=list(coordinate_units="cm",coordinate_system="tank"),
 uncertainty=list(path_sensitivity=data.frame(
  session_id=rep("S",36),camera_id=rep("C",36),
  track_id=sprintf("F%03d",1:36),
  scenario_q025=seq_len(36),scenario_q975=seq_len(36)+2,
  scenario_median=seq_len(36)+1)))
test_that("figure-axis helpers reject unknown numeric support and disclose source units",{
 axis <- aquaTrajectories:::.aqt_publication_axis
 units <- aquaTrajectories:::.aqt_publication_units
 expect_error(axis(numeric()),"No finite plotting values")
 expect_error(axis(c(NA_real_,Inf)),"No finite plotting values")
 expect_equal(diff(axis(rep(0,3))),.02,tolerance=1e-12)
 expect_true(all(is.finite(axis(c(-Inf,0,Inf,1)))))
 expect_identical(units(list(provenance=list(coordinate_units=NULL)))$position,
                 "source units")
 expect_identical(units(list(provenance=list(coordinate_units="")))$speed,
                 "source units/s")
 expect_identical(units(.cov100_pub_minimal())$position,"cm")
})
test_that("figure renderer recovers device and removes failed outputs",{
 study <- .cov100_pub_minimal()
 row <- data.frame(kind="not-an-eligible-figure",session_id="S",camera_id="C")
 render <- aquaTrajectories:::.aqt_publication_render
 start <- grDevices::dev.cur()
 file <- tempfile(fileext=".pdf")
 result <- render(study,row,file,"pdf",7,5,200)
 expect_false(result$ok)
 expect_match(result$reason,"Unknown figure kind")
 expect_identical(grDevices::dev.cur(),start)
 expect_false(file.exists(file))
 expect_error(aquaTrajectories:::.aqt_publication_draw(study,row),
              "Unknown figure kind")
 # Unwritable nested target should fail without leaving a partial graphic.
 badfile <- file.path(tempdir(),"cov100_nonexistent_parent",
                      "failure.pdf")
 fail <- render(study,row,badfile,"pdf",7,5,200)
 expect_false(fail$ok)
 expect_false(file.exists(badfile))
})
test_that("conditional sensitivity drawing caps labels at 35, with raw rows unchanged", {
 study <- .cov100_pub_minimal()
 row <- data.frame(kind="sensitivity",session_id="S",camera_id="C")
 before <- serialize(study$uncertainty$path_sensitivity,NULL)
 path <- tempfile(fileext=".pdf")
 grDevices::pdf(path,width=11,height=9)
 on.exit({grDevices::dev.off();unlink(path)},add=TRUE)
 expect_invisible(aquaTrajectories:::.aqt_publication_draw(study,row))
 expect_identical(serialize(study$uncertainty$path_sensitivity,NULL),before)
 bad <- study
 bad$uncertainty$path_sensitivity$scenario_q025 <- NA_real_
 bad$uncertainty$path_sensitivity$scenario_q975 <- NA_real_
 expect_error(aquaTrajectories:::.aqt_publication_draw(bad,row),
              "No finite plotting values")
})

test_that("publication figure device reports a missing PDF instead of success",{
 study <- .cov100_pub_minimal()
 row <- data.frame(kind="sensitivity",session_id="S",camera_id="C")
 file <- tempfile("cov100_missing_device_",fileext=".pdf")
 on.exit(unlink(file),add=TRUE)
 checked <- 0L
 testthat::with_mocked_bindings({
   output <- aquaTrajectories:::.aqt_publication_render(
      study,row,file,"pdf",7,5,200)
   expect_false(output$ok)
   expect_match(output$reason,"did not emit a usable file")
 },file.exists=function(path) {
   if(identical(path,file)) {
     checked <<- checked+1L
     if(checked==1L) return(FALSE)
   }
   base::file.exists(path)
 },.package="aquaTrajectories")
 expect_gt(checked,0L)
})
