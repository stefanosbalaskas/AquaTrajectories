# Distinguish offered options from actual exercise without attributing agency.
.cov100_aci_fixture <- function() {
  d <- expand.grid(fish_id=c("F1","F2"),trial_id=c("T1","T2"),
                   option_id=c("A","B"),KEEP.OUT.ATTRS=FALSE,
                   stringsAsFactors=FALSE)
  d$session_id <- "S"
  d$tank_id <- "tank"
  d$trial_s <- ifelse(d$trial_id=="T1",0,10)
  d$trial_end_s <- d$trial_s+5
  d$offered <- TRUE
  d$selected <- d$fish_id=="F1" & d$option_id=="B" & d$trial_id=="T1"
  d$choice_s <- ifelse(d$selected,d$trial_s+1,NA_real_)
  d
}
test_that("animal choice opportunities preserve independent offered and exercised events",{
 d <- .cov100_aci_fixture()
 expect_error(aqt_aci_choice_log(data.frame(x=1)),"Expected an ACI")
 bad <- d;bad$fish_id[1] <- NA_character_
 expect_error(aqt_aci_choice_log(bad),"identifiers must be nonmissing")
 bad <- d;bad$option_id[1] <- ""
 expect_error(aqt_aci_choice_log(bad),"identifiers must be nonmissing")
 bad <- d;bad$trial_end_s[1] <- bad$trial_s[1]
 expect_error(aqt_aci_choice_log(bad),"window is nonpositive")
 bad <- d;bad$trial_s <- as.character(bad$trial_s)
 expect_error(aqt_aci_choice_log(bad),"timestamps are invalid")
 bad <- d;bad$choice_s[1] <- Inf
 expect_error(aqt_aci_choice_log(bad),"timestamps are invalid")
 bad <- d;bad$offered <- as.integer(bad$offered)
 expect_error(aqt_aci_choice_log(bad),"indicators must be nonmissing logical")
 bad <- d;bad$selected[1] <- NA
 expect_error(aqt_aci_choice_log(bad),"indicators must be nonmissing logical")
 bad <- d;bad$offered[bad$selected] <- FALSE
 expect_error(aqt_aci_choice_log(bad),"unavailable option cannot be selected")
 bad <- d;bad$choice_s[bad$selected] <- NA_real_
 expect_error(aqt_aci_choice_log(bad),"Choice timestamps required")
 bad <- d;bad$choice_s[!bad$selected][1] <- 1
 expect_error(aqt_aci_choice_log(bad),"Choice timestamps required")
 bad <- d;bad$choice_s[bad$selected] <- -1
 expect_error(aqt_aci_choice_log(bad),"outside its opportunity window")
 bad <- rbind(d,d[1,,drop=FALSE])
 expect_error(aqt_aci_choice_log(bad),"Duplicate option within")
 bad <- d;bad$trial_end_s[1] <- bad$trial_end_s[1]+1
 expect_error(aqt_aci_choice_log(bad),"fixed tank and event window")
 bad <- d;bad$offered[d$fish_id=="F2" & d$trial_id=="T1"] <- FALSE
 expect_error(aqt_aci_choice_log(bad),"at least one offered option")
 bad <- d
 idx <- which(d$fish_id=="F1" & d$trial_id=="T1" & d$option_id=="A")
 bad$selected[idx] <- TRUE;bad$choice_s[idx] <- 1
 expect_error(aqt_aci_choice_log(bad),"Multiple selected options")
 bad <- d;bad$tank_id[d$fish_id=="F1" & d$trial_id=="T2"] <- "other"
 expect_error(aqt_aci_choice_log(bad),"cannot change its tank")
 valid <- aqt_aci_choice_log(d)
 summary <- aqt_aci_choice_summary(valid)
 expect_equal(nrow(summary$per_fish),2L)
 expect_equal(summary$per_fish$n_multichoice_opportunities,c(2L,2L))
 expect_true(any(summary$per_fish$n_exercised_multichoice==1L))
 expect_true(any(summary$per_fish$n_exercised_multichoice==0L))
 expect_true(any(summary$per_option$n_selected==0L))
 expect_false(summary$welfare_inferred)
 expect_false(attr(valid,"animal_agency_claimed"))
})
test_that("access inequality treats zero choices as undefined not zero inequality",{
 d <- .cov100_aci_fixture()
 valid <- aqt_aci_choice_log(d)
 g <- aqt_aci_access_inequality(valid)
 expect_equal(g$n_fish,2L)
 expect_equal(g$gini_exercise_rate,.5,tolerance=1e-12)
 expect_false(g$dominance_or_welfare_inferred)
 no <- d;no$selected[] <- FALSE;no$choice_s[] <- NA_real_
 empty <- aqt_aci_access_inequality(aqt_aci_choice_log(no))
 expect_true(is.na(empty$gini_exercise_rate))
 single <- d[d$fish_id=="F1",,drop=FALSE]
 expect_error(aqt_aci_access_inequality(aqt_aci_choice_log(single)),
              "At least two fish")
 not_offered <- d
 not_offered$offered[not_offered$fish_id=="F2" & not_offered$option_id=="B"] <- FALSE
 expect_error(aqt_aci_access_inequality(aqt_aci_choice_log(not_offered)),
              "multi-option opportunities required")
 expect_error(aqt_aci_choice_summary(list()),"Expected an aqt_aci_choice_log")
})
