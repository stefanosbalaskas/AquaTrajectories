# Research publication tests only republish previously calculated synthetic
# results. A successful renderer does not authenticate biological truth.
.cov100_pub_study <- function() {
 frames <- do.call(rbind,lapply(c("T1","T2"),function(tank)
   data.frame(session_id=tank,camera_id="TOP",frame_id=0:4,
     time_s=(0:4)/5,width_px=100,height_px=100)))
 tracks <- do.call(rbind,lapply(c("T1","T2"),function(tank)
    do.call(rbind,lapply(c("01","02"),function(fish)
      data.frame(session_id=tank,camera_id="TOP",
        track_id=fish,frame_id=0:4,time_s=(0:4)/5,
        x=(0:4)+if(fish=="01")0 else 2,y=if(tank=="T1")1 else 3,
        observed=TRUE,detection_confidence=.9)))))
 review <- aqt_qc_review(aqt_trajectory_qc(tracks,frames,max_gap_s=.21))
 aqt_research_analyze(review,profiles=c("movement","schooling"))
}
test_that("publication settings refuse invalid figure dimensions, output scopes and formats", {
 study <- .cov100_pub_study()
 parent <- tempfile("cov100_pub_parent_")
 dir.create(parent)
 on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
 folder <- file.path(parent,"publication")
 call <- function(path=folder,...)aqt_research_publish(study,path,...)
 expect_error(aqt_research_publish(list(),folder),"scientific|source")
 expect_error(call(path=parent),"new with an existing parent")
 expect_error(call(path=file.path(parent,"missing","result")),
              "new with an existing parent")
 expect_error(call(path=NA_character_),"new with an existing parent")
 expect_error(call(path=""),"new with an existing parent")
 expect_error(call(formats=character()),"unique nonempty png/pdf")
 expect_error(call(formats=c("pdf","pdf")),"unique nonempty png/pdf")
 expect_error(call(formats="tiff"),"unique nonempty png/pdf")
 expect_error(call(formats=NA_character_),"unique nonempty png/pdf")
 expect_error(call(width=2.9),"finite 3..15")
 expect_error(call(width=15.1),"finite 3..15")
 expect_error(call(height=Inf),"finite 3..15")
 expect_error(call(height=NA_real_),"finite 3..15")
 expect_error(call(dpi=99),"integer 100..600")
 expect_error(call(dpi=601),"integer 100..600")
 expect_error(call(dpi=150.5),"integer 100..600")
 expect_error(call(dpi=NA_real_),"integer 100..600")
 expect_error(call(data_origin="authenticated_real"),"arg")
 # These validations must not leave an output folder behind.
 expect_false(dir.exists(folder))
})
test_that("publication emits a complete versioned report and no fabricated source estimates", {
 study <- .cov100_pub_study()
 parent <- tempfile("cov100_pub_parent_")
 dir.create(parent)
 on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
 original <- digest::digest(study$review$qc$raw,algo="sha256",serialize=TRUE)
 output <- file.path(parent,"publication")
 expect_invisible(aqt_research_publish(study,output,formats="pdf",
       max_scopes=1,data_origin="synthetic"))
 expect_true(dir.exists(output))
 expect_true(file.exists(file.path(output,"REPORT.md")))
 expect_true(file.exists(file.path(output,"PUBLICATION_MANIFEST.json")))
 expect_true(file.exists(file.path(output,"FIGURE_CATALOG.csv")))
 expect_true(file.exists(file.path(output,"tables","T01_QC_COUNTS.csv")))
 expect_true(file.exists(file.path(output,"tables","T02_PROFILE_DECISIONS.csv")))
 expect_true(file.exists(file.path(output,"analysis","reproducibility",
          "ANALYSIS_MANIFEST.json")))
 catalog <- utils::read.csv(file.path(output,"FIGURE_CATALOG.csv"),
                            stringsAsFactors=FALSE)
 expect_true(all(catalog$status %in% c("complete","skipped","failed")))
 expect_true(all(catalog$files[catalog$status=="skipped"]==""))
 report <- readLines(file.path(output,"REPORT.md"),warn=FALSE)
 expect_true(any(grepl("Declared data origin: synthetic",report,fixed=TRUE)))
 expect_true(any(grepl("not independently validated",report,fixed=TRUE)))
 manifest <- jsonlite::fromJSON(file.path(output,"PUBLICATION_MANIFEST.json"),
                                 simplifyVector=FALSE)
 expect_identical(manifest$declared_data_origin,"synthetic")
 expect_false(manifest$independent_data_origin_verified)
 expect_identical(manifest$original_raw_sha256,original)
 expect_identical(digest::digest(study$review$qc$raw,
             algo="sha256",serialize=TRUE),original)
 expect_error(aqt_research_publish(study,output,formats="pdf"),
              "new with an existing parent")
})
test_that("publication Markdown sanitizes pipe, newlines and missing values", {
 scrub <- aquaTrajectories:::.aqt_pub_markdown_value
 tab <- aquaTrajectories:::.aqt_pub_markdown_table
 expect_identical(scrub(c("a|b","c\nd",NA_character_)),c("a b","c d","NA"))
 expect_identical(tab(data.frame()),"No rows available.")
 valid <- data.frame(name=c("fish|A",NA_character_),
                     estimate=c(1.23456789,NA_real_))
 out <- tab(valid)
 expect_match(out,"fish A",fixed=TRUE)
 expect_match(out,"1.23457",fixed=TRUE)
 expect_match(out,"NA",fixed=TRUE)
 expect_false(grepl("fish|A",out,fixed=TRUE))
});
