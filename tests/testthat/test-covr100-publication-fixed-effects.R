# This fixture is an explicitly fabricated serialization stress test.
# The numbers below are not estimated coefficients, scientific findings
# or independently measured fish/tank responses.
.cov100_fixed_effect_study <- function() {
 f <- data.frame(session_id="S",camera_id="C",frame_id=0:3,
     time_s=0:3/10,width_px=100,height_px=80)
 d <- data.frame(session_id="S",camera_id="C",track_id="F",
     frame_id=0:3,time_s=0:3/10,x=10:13,y=20,
     observed=TRUE,detection_confidence=.9)
 review <- aqt_qc_review(aqt_trajectory_qc(d,f,max_gap_s=.11))
 study <- aqt_research_analyze(review,profiles="movement")
 # Inject a distinct, EXPLICITLY SYNTHETIC model summary to test the
 # publication serializer, never the inferential estimator.
 fx <- matrix(c(.25,.05),ncol=1,
              dimnames=list(c("(Intercept)","time_s"),"Estimate"))
 study$statistical_models <- list(
   design_audit=data.frame(treatment="synthetic",n_tanks=1),
   functional_model=list(fixed_effects=fx))
 study
}
test_that("research publisher serializes synthetic matrix fixed effects without refitting",{
 study <- .cov100_fixed_effect_study()
 before <- serialize(study,NULL)
 parent <- tempfile("cov100_effects_");dir.create(parent)
 on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
 dest <- file.path(parent,"publication")
 expect_invisible(aqt_research_publish(study,dest,formats="pdf",
                    data_origin="synthetic"))
 result <- file.path(dest,"tables","T12_FUNCTIONAL_MODEL_FIXED_EFFECTS.csv")
 expect_true(file.exists(result))
 fixed <- utils::read.csv(result,stringsAsFactors=FALSE)
 expect_identical(fixed$term,c("(Intercept)","time_s"))
 expect_equal(fixed$Estimate,c(.25,.05))
 expect_identical(serialize(study,NULL),before)
 manifest <- jsonlite::fromJSON(file.path(dest,"PUBLICATION_MANIFEST.json"),
                    simplifyVector=FALSE)
 expect_identical(manifest$declared_data_origin,"synthetic")
 expect_false(manifest$independent_data_origin_verified)
})
