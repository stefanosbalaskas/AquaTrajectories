# A controlled second writer races an output directory AFTER validation.
# Atomic figure publishing must refuse an occupied nonempty destination and
# clean its staging directory without changing the original source.
test_that("atomic figure export aborts when a concurrent writer occupies destination",{
 parent <- tempfile("cov100_figure_race_")
 dir.create(parent)
 on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
 destination <- file.path(parent,"figure")
 draw <- function() {
   graphics::plot(0:4,0:4,type="b")
   if(!dir.exists(destination))dir.create(destination)
   writeLines("external writer owns this path",
              file.path(destination,"writer.txt"))
 }
 expect_error(suppressWarnings(aqt_figure_export(draw,destination,
                 formats="pdf",width=4,height=4)),
              "Cannot move validated output directory")
 expect_true(file.exists(file.path(destination,"writer.txt")))
 expect_false(file.exists(file.path(destination,"FIGURE_MANIFEST.json")))
 remnants <- list.files(parent,all.files=TRUE)
 expect_false(any(grepl("^\\.aqt-figure-",remnants)))
})
