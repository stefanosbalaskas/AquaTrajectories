# Source-resolved, purely provisional cross-camera associations.
# A stable software track label is never treated as confirmed animal identity.
.cov100_assoc <- function() {
 z <- data.frame(candidate_id=paste0("C",1:3),
    session_id="S",id_a="A",id_b="B",
    time_a_s=0:2,time_b_s=0:2,time_skew_s=0,
    ray_separation=c(.02,.03,.04),valid=TRUE,
    stringsAsFactors=FALSE)
 attr(z,"aqt_units") <- "cm"
 z
}
test_that("crossview association enforces original source, matching and units",{
 d <- .cov100_assoc()
 expect_error(aqt_crossview_auto_associate(list()),"Expected exact geometric")
 expect_error(aqt_crossview_auto_associate(data.frame(x=1)),"Expected exact geometric")
 expect_error(aqt_crossview_auto_associate(d,min_support=0),"Invalid minimum support")
 expect_error(aqt_crossview_auto_associate(d,min_support=1.5),"Invalid minimum support")
 expect_error(aqt_crossview_auto_associate(d,max_error=-1),"Invalid minimum support")
 expect_error(aqt_crossview_auto_associate(d,ambiguity_margin=-1),"Invalid minimum support")
 bad <- d;bad$candidate_id[2] <- bad$candidate_id[1]
 expect_error(aqt_crossview_auto_associate(bad),"Invalid original candidate")
 bad <- d;bad$valid[2] <- NA
 expect_error(aqt_crossview_auto_associate(bad),"Invalid original candidate")
 bad <- d;bad$valid <- as.integer(bad$valid)
 expect_error(aqt_crossview_auto_associate(bad),"Invalid original candidate")
 bad <- d;bad$time_skew_s[2] <- 1
 expect_error(aqt_crossview_auto_associate(bad),"Invalid original candidate")
 bad <- d;bad$time_skew_s[2] <- -1
 expect_error(aqt_crossview_auto_associate(bad),"Invalid original candidate")
 bad <- d;bad$time_a_s[1] <- Inf
 expect_error(aqt_crossview_auto_associate(bad),"Invalid original candidate")
 bad <- d;bad$id_a[1] <- ""
 expect_error(aqt_crossview_auto_associate(bad),"Cross-camera source IDs cannot")
 bad <- d;bad$id_b[1] <- NA_character_
 expect_error(aqt_crossview_auto_associate(bad),"Cross-camera source IDs cannot")
 good <- aqt_crossview_auto_associate(d)
 expect_equal(nrow(good$links),1)
 expect_equal(good$links$n_supported_observations,3)
 expect_equal(nrow(good$correspondences),3)
 expect_false(good$independent_biological_identity_certified)
 expect_false(good$clock_synchronization_verified)
 expect_identical(good$geometry_error_unit,"cm")
})
test_that("crossview candidate support avoids false one-to-many fish identities",{
 d <- .cov100_assoc()
 rejected <- d;rejected$valid[] <- FALSE
 result <- aqt_crossview_auto_associate(rejected)
 expect_equal(nrow(result$links),0)
 expect_equal(result$n_valid_candidates,0L)
 unsupported <- aqt_crossview_auto_associate(d,min_support=4)
 expect_equal(nrow(unsupported$links),0L)
 expect_equal(unsupported$n_valid_candidates,3L)
 repeated <- rbind(d,transform(d[1,,drop=FALSE],candidate_id="C4"))
 attr(repeated,"aqt_units") <- "cm"
 same <- aqt_crossview_auto_associate(repeated)
 expect_equal(same$links$n_supported_observations,3)
 expect_equal(nrow(same$correspondences),3)
 # Competing A->B and A->C pairs have indistinguishable support/geometry.
 rival <- transform(d,candidate_id=paste0("R",1:3),id_b="C")
 both <- rbind(d,rival)
 attr(both,"aqt_units") <- "cm"
 abstain <- aqt_crossview_auto_associate(both,ambiguity_margin=.1)
 expect_gt(abstain$n_ambiguous_abstentions,0)
 expect_equal(nrow(abstain$links),0)
 # Two distinct source tracks can each support a distinct provisional link.
 independent <- transform(d,candidate_id=paste0("D",1:3),
                          id_a="C",id_b="D")
 paired <- rbind(d,independent)
 attr(paired,"aqt_units") <- "cm"
 out <- aqt_crossview_auto_associate(paired)
 expect_equal(nrow(out$links),2)
 expect_equal(length(unique(out$correspondences$fish_id)),2)
 expect_true(all(out$links$n_supported_observations==3))
 # Pinhole reprojection candidates retain pixel error units.
 pin <- d
 pin$reprojection_rmse_px <- pin$ray_separation
 pin$ray_separation <- NULL
 attr(pin,"aqt_units") <- NULL
 out_px <- aqt_crossview_auto_associate(pin,max_error=1)
 expect_identical(out_px$geometry_error_unit,"px")
 expect_equal(nrow(out_px$links),1)
 empty_px <- aqt_crossview_auto_associate(pin,min_support=4)
 expect_identical(empty_px$geometry_error_unit,"px")
 expect_equal(nrow(empty_px$links),0)
})
