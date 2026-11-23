# Fault-injection publishing tests: a graphics failure must be documented
# and partially emitted images removed before a report is finalized.
.cov100_fault_study <- function() {
 f <- data.frame(session_id="S",camera_id="TOP",frame_id=0:5,
     time_s=(0:5)/10,width_px=100,height_px=80)
 obs <- do.call(rbind,lapply(c("F1","F2"),function(fish)
  data.frame(session_id="S",camera_id="TOP",frame_id=0:5,
       track_id=fish,time_s=(0:5)/10,
       x=0:5,y=if(fish=="F1")1 else 4,
       observed=TRUE,detection_confidence=.9)))
 review <- aqt_qc_review(aqt_trajectory_qc(obs,f,max_gap_s=.11))
 aqt_research_analyze(review,profiles=c("movement","schooling"))
}
test_that("failed figure renderer is reported without claiming a complete public figure", {
 study <- .cov100_fault_study()
 plan <- aqt_research_figure_plan(study,max_scopes=1)
 expect_true(any(plan$eligible))
 root <- tempfile("cov100_fault_publish_")
 dir.create(root)
 on.exit(unlink(root,recursive=TRUE,force=TRUE),add=TRUE)
 target <- file.path(root,"publication")
 testthat::local_mocked_bindings(
    .aqt_publication_render=function(...) {
      list(ok=FALSE,reason="Synthetic device failure, no published figure")
    },.package="aquaTrajectories")
 expect_invisible(aqt_research_publish(study,target,
             data_origin="synthetic",formats=c("pdf","png"),
             max_scopes=1))
 catalog <- utils::read.csv(file.path(target,"FIGURE_CATALOG.csv"),
          stringsAsFactors=FALSE)
 expect_true(any(catalog$status=="failed"))
 expect_true(all(is.na(catalog$files[catalog$status=="failed"]) | catalog$files[catalog$status=="failed"]==""))
 expect_true(all(grepl("Synthetic device failure",
              catalog$reason[catalog$status=="failed"],fixed=TRUE)))
 meta <- jsonlite::fromJSON(file.path(target,"PUBLICATION_MANIFEST.json"))
 expect_gt(meta$n_figures_failed,0)
 expect_false(meta$independent_data_origin_verified)
})
test_that("failure after first figure device removes already emitted partial files",{
 study <- .cov100_fault_study()
 root <- tempfile("cov100_partial_publish_")
 dir.create(root)
 on.exit(unlink(root,recursive=TRUE,force=TRUE),add=TRUE)
 target <- file.path(root,"publication")
 testthat::local_mocked_bindings(
     .aqt_publication_render=function(study,row,file,format,width,height,dpi) {
       if(format=="pdf") {
         writeLines("SYNTHETIC PARTIAL FILE; SHOULD NOT SURVIVE",file)
         return(list(ok=TRUE,reason=""))
       }
       list(ok=FALSE,reason="Synthetic second-device failure")
     },.package="aquaTrajectories")
 expect_invisible(aqt_research_publish(study,target,
      data_origin="synthetic",formats=c("pdf","png"),max_scopes=1))
 catalog <- utils::read.csv(file.path(target,"FIGURE_CATALOG.csv"),
          stringsAsFactors=FALSE)
 expect_gt(sum(catalog$status=="failed"),0)
 expect_equal(length(list.files(file.path(target,"figures"),
                  pattern="[.]pdf$")),0L)
 expect_true(file.exists(file.path(target,"REPORT.md")))
});
