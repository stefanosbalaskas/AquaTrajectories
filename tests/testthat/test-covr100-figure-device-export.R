# Device-qualified figure export reproduces the exact same drawing calls
# without modifying raw scientific sources or inventing missing observations.
.cov100_export_draw <- function() {
 graphics::plot(0:5,c(1,2,2,3,4,5),type="b",
                main="Synthetic scientific figure",
                xlab="Original source index",ylab="Source value")
}
test_that("figure export rejects invalid paths, devices and source provenance", {
 parent <- tempfile("cov100_figure_parent_");dir.create(parent)
 on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
 target <- file.path(parent,"export")
 call <- function(draw=.cov100_export_draw,path=target,...)
    aqt_figure_export(draw,path,...)
 expect_error(call(draw=function(x) graphics::plot(x)),
              "zero-argument")
 expect_error(call(draw=list()),"zero-argument")
 expect_error(call(path=parent),"new path")
 expect_error(call(path=file.path(parent,"uncreated","figure")),"new path")
 expect_error(call(path=NA_character_),"new path")
 expect_error(call(formats=character()),"unique values")
 expect_error(call(formats=c("pdf","pdf")),"unique values")
 expect_error(call(formats="eps"),"unique values")
 expect_error(call(formats=NA_character_),"unique values")
 expect_error(call(width=1.9),"2..20")
 expect_error(call(width=20.1),"2..20")
 expect_error(call(height=Inf),"2..20")
 expect_error(call(dpi=70),"integer 72..1200")
 expect_error(call(dpi=1201),"integer 72..1200")
 expect_error(call(dpi=100.5),"integer 72..1200")
 expect_error(call(caption=NA_character_),"character scalar")
 expect_error(call(caption=c("one","two")),"character scalar")
 expect_error(call(source_file=parent),"existing file")
 expect_error(call(source_file=file.path(parent,"absent.csv")),"existing file")
 expect_false(dir.exists(target))
})
test_that("figure export cleans failures and preserves original source bytes", {
 parent <- tempfile("cov100_figure_parent_");dir.create(parent)
 on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
 source <- file.path(parent,"original.csv")
 writeLines("fish_id,x\nF001,2",source)
 before <- digest::digest(source,file=TRUE,algo="sha256")
 path <- file.path(parent,"bad")
 expect_error(aqt_figure_export(function() stop("intended synthetic failure"),
    path,formats="pdf"),"intended synthetic failure")
 expect_false(dir.exists(path))
 good <- file.path(parent,"complete")
 expect_invisible(aqt_figure_export(.cov100_export_draw,good,
    formats="pdf",caption="Synthetic and descriptive",source_file=source))
 expect_true(file.exists(file.path(good,"figure.pdf")))
 expect_true(file.exists(file.path(good,"FIGURE_MANIFEST.json")))
 m <- jsonlite::fromJSON(file.path(good,"FIGURE_MANIFEST.json"),
                        simplifyVector=FALSE)
 expect_identical(m$schema,"AQT_FIGURE_EXPORT_V1")
 expect_identical(m$source_file_sha256,before)
 expect_false(m$source_measurement_certified)
 expect_identical(digest::digest(source,file=TRUE,algo="sha256"),before)
 expect_error(aqt_figure_export(.cov100_export_draw,good),
              "new path")
})
test_that("raster and vector devices produce nonempty independent outputs",{
 if(!requireNamespace("ragg",quietly=TRUE)||
    !requireNamespace("svglite",quietly=TRUE))
   testthat::skip("Optional scientific graphic devices are not installed")
 parent <- tempfile("cov100_graphics_");dir.create(parent)
 on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
 target <- file.path(parent,"all")
 expect_invisible(aqt_figure_export(.cov100_export_draw,target,
    formats=c("png","svg","tiff"),width=3,height=3,dpi=100))
 for(ext in c("png","svg","tiff")) {
   path <- file.path(target,paste0("figure.",ext))
   expect_true(file.exists(path))
   expect_gt(file.info(path)$size,100)
 }
 manifest <- jsonlite::fromJSON(file.path(target,"FIGURE_MANIFEST.json"),
                      simplifyVector=FALSE)
 expect_equal(length(manifest$output_sha256),3L)
 expect_equal(length(unique(unlist(manifest$output_sha256))),3L)
})
