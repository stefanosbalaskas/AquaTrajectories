# Independent synthetic geometry-candidate ranking, not biological identity.
.cov100_review_candidates <- function() {
 data.frame(candidate_id=paste0("C",1:4),
   session_id="S",id_a="A",id_b=c("B","C","B","C"),
   time_a_s=c(0,0,1,1),time_b_s=c(0,0,1,1),
   time_skew_s=0,reprojection_rmse_px=c(.2,.4,.5,.1),
   valid=TRUE,stringsAsFactors=FALSE)
}
test_that("candidate ranking makes insufficient/ambiguous support explicit", {
 d <- .cov100_review_candidates()
 expect_error(aqt_candidate_rank(list()),"Invalid candidate")
 expect_error(aqt_candidate_rank(data.frame(x=1)),"Invalid candidate")
 expect_error(aqt_candidate_rank(d,max_reprojection_px=-1),"finite and nonnegative")
 expect_error(aqt_candidate_rank(d,max_reprojection_px=Inf),"finite and nonnegative")
 expect_error(aqt_candidate_rank(d,max_reprojection_px=NA_real_),"finite and nonnegative")
 empty <- aqt_candidate_rank(d[0,,drop=FALSE])
 expect_equal(nrow(empty),0)
 expect_true(all(c("eligible","rank_a","n_eligible_a","best_margin_px") %in% names(empty)))
 bad <- d;bad$candidate_id[1] <- bad$candidate_id[2]
 expect_error(aqt_candidate_rank(bad),"Invalid or repeated")
 bad <- d;bad$valid[1] <- NA
 expect_error(aqt_candidate_rank(bad),"Invalid or repeated")
 bad <- d;bad$valid <- as.integer(bad$valid)
 expect_error(aqt_candidate_rank(bad),"Invalid or repeated")
 ranked <- aqt_candidate_rank(d,max_reprojection_px=.25)
 expect_equal(sum(ranked$eligible),2)
 expect_true(all(ranked$n_eligible_a==1))
 expect_true(all(is.infinite(ranked$best_margin_px)))
 none <- aqt_candidate_rank(d,max_reprojection_px=.01)
 expect_false(any(none$eligible))
 expect_true(all(is.na(none$rank_a)))
 expect_true(all(none$n_eligible_a==0))
 ranked2 <- aqt_candidate_rank(d,max_reprojection_px=2)
 expect_equal(sum(ranked2$eligible),4)
 expect_equal(ranked2$rank_a[1],1L)
 expect_equal(ranked2$rank_a[4],1L)
 expect_true(all(is.finite(ranked2$best_margin_px)))
})
test_that("human-reviewed correspondence file never invents an animal match", {
 d <- .cov100_review_candidates()
 expect_error(aqt_correspondences_from_review(d,data.frame(x=1)),
              "must be a data frame with")
 review <- data.frame(candidate_id=c("C1","C4"),
      fish_id=c("verified-X","verified-Y"),reviewer="reviewer",
      reason="independent manual review",stringsAsFactors=FALSE)
 out <- aqt_correspondences_from_review(d,review)
 expect_equal(nrow(out),2)
 expect_true(all(c("reviewer","reason","candidate_id") %in% names(out)))
 expect_identical(out$fish_id,review$fish_id)
 empty <- review[0,,drop=FALSE]
 expect_error(aqt_correspondences_from_review(d,empty),"Review must select")
 dup <- rbind(review,review[1,,drop=FALSE])
 expect_error(aqt_correspondences_from_review(d,dup),"Review must select")
 blank <- review;blank$reviewer[1] <- ""
 expect_error(aqt_correspondences_from_review(d,blank),"Reviews require fish_id")
 missing <- review;missing$candidate_id[1] <- "NONEXISTENT"
 expect_error(aqt_correspondences_from_review(d,missing),"Reviewed candidate missing")
 bad <- d;bad$valid[1] <- FALSE
 expect_error(aqt_correspondences_from_review(bad,review),"invalid stereo geometry")
 conflict <- review;conflict$candidate_id[2] <- "C2"
 expect_error(aqt_correspondences_from_review(d,conflict),"source observation cannot be")
 bad <- d;bad$candidate_id[2] <- bad$candidate_id[1]
 expect_error(aqt_correspondences_from_review(bad,review),"Reviewed candidate missing")
})
