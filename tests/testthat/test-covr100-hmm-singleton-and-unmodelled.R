# Gaussian-HMM fault cases use original synthetic observations; decoding
# conditional latent states never labels fish welfare.
.cov100_hmm_direct <- function() {
 data.frame(session_id="S",camera_id="C",track_id="A",
 time_s=0:5,speed=c(.1,.2,.3,8,8.2,8.5),
 observed=TRUE,tank_id="T",treatment="control")
}
test_that("HMM source preparation blocks pre-existing output, treatment drift and empty fish scopes",{
 src <- .cov100_hmm_direct()
 make <- aquaTrajectories:::.aqt_hmm_prepare
 expect_error(make(src[FALSE,,drop=FALSE],"speed",1.1,2),
              "Expected nonempty scoped")
 bad <- src;bad$hmm_p1 <- 0
 expect_error(make(bad,"speed",1.1,2),"Existing HMM output columns")
 bad <- src;bad$treatment[1] <- "treatment"
 expect_error(make(bad,"speed",1.1,2),"Treatment must not change")
 prepared <- make(src,"speed",1.1,2)
 expect_equal(length(unique(stats::na.omit(prepared$hmm_segment))),1L)
})
test_that("HMM decoding of a single sample and zero-likelihood sequence fails explicitly",{
 decode <- aquaTrajectories:::.aqt_hmm_segment_decode
 m <- matrix(c(.9,.1,.1,.9),2,2,byrow=TRUE)
 single <- decode(y=.2,means=c(0,8),sds=c(.5,.5),
                  transition=m,initial=c(.5,.5))
 expect_equal(dim(single$posterior),c(1L,2L))
 expect_equal(sum(single$posterior),1,tolerance=1e-12)
 expect_equal(length(single$path),1)
 expect_error(decode(y=1e308,means=c(0,8),sds=c(.5,.5),
              transition=m,initial=c(.5,.5)),
              "nonfinite sequence likelihood")
})
test_that("HMM summary refuses an entirely unclassified source fish",{
 src <- .cov100_hmm_direct()
 decoded <- aqt_hmm_decode(src,state_means=c(0,8),
             state_sds=c(.5,.5),transition=matrix(c(.9,.1,.1,.9),2,2,byrow=TRUE),max_gap_s=.5,min_segment=4)
 expect_error(aqt_hmm_state_summary(decoded),
              "No decoded fish states")
 # A second fish can be unclassified while valid fish keep their own denominator.
 src2 <- src;src2$track_id <- "B";src2$observed[] <- FALSE
 d <- rbind(src,src2)
 decoded <- aqt_hmm_decode(d,state_means=c(0,8),
             state_sds=c(.5,.5),transition=matrix(c(.9,.1,.1,.9),2,2,byrow=TRUE),max_gap_s=1.1,min_segment=4)
 s <- aqt_hmm_state_summary(decoded)
 expect_equal(length(unique(s$track_id)),1L)
 expect_identical(unique(s$track_id),"A")
 expect_false(attr(s,"aqt_hmm_independent_tank_test"))
});
