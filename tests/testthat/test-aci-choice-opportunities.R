.aqt_aci_choice_fixture <- function() {
  rows <- list();k <- 0L
  for (fish in c("F1","F2")) for (j in 1:3) {
    t <- (j-1)*10
    chosen <- if (fish=="F1" && j<=2) "A" else
      if (fish=="F2" && j==1) "B" else ""
    for (option in c("A","B","C")) {
      k <- k+1L
      selected <- identical(chosen,option)
      rows[[k]] <- data.frame(session_id="S",tank_id="T",
        fish_id=fish,trial_id=paste0("trial",j),
        option_id=option,trial_s=t,trial_end_s=t+5,
        offered=option!="C",selected=selected,
        choice_s=if(selected)t+1 else NA_real_)
    }
  }
  do.call(rbind,rows)
}

test_that("ACI choice logs separate offered vs exercised and unavailable options", {
  d <- .aqt_aci_choice_fixture()
  out <- aqt_aci_choice_log(d)
  expect_s3_class(out,"aqt_aci_choice_log")
  expect_equal(nrow(out),18)
  expect_equal(sum(out$offered),12)
  expect_equal(sum(out$selected),3)
  expect_true(all(out$choice_latency_s[out$selected]==1))
  expect_true(all(is.na(out$choice_latency_s[!out$selected])))
  expect_false(attr(out,"animal_agency_claimed"))
  result <- aqt_aci_choice_summary(out)
  expect_equal(nrow(result$per_trial),6)
  expect_true(all(result$per_trial$n_offered==2))
  expect_equal(result$per_fish$n_multichoice_opportunities,c(3,3))
  expect_equal(result$per_fish$n_exercised_multichoice,c(2,1))
  expect_equal(result$per_fish$multichoice_exercise_rate,c(2/3,1/3))
  expect_equal(result$per_fish$median_choice_latency_s,c(1,1))
  a <- result$per_option[
    result$per_option$fish_id=="F1" &
    result$per_option$option_id=="A",]
  expect_equal(a$n_offered,3)
  expect_equal(a$n_selected,2)
  expect_equal(a$selection_given_offered,2/3)
  expect_false(result$welfare_inferred)
})

test_that("multi-option usage inequality reports exposure balance without welfare claims", {
  log <- aqt_aci_choice_log(.aqt_aci_choice_fixture())
  stats <- aqt_aci_access_inequality(log)
  expect_equal(stats$n_fish,2)
  expect_equal(stats$mean_exercise_rate,.5)
  expect_equal(stats$gini_exercise_rate,1/6,tolerance=1e-12)
  expect_true(stats$opportunities_balanced)
  expect_false(stats$dominance_or_welfare_inferred)
  d <- .aqt_aci_choice_fixture()
  d$selected[] <- FALSE
  d$choice_s[] <- NA_real_
  quiet <- aqt_aci_access_inequality(aqt_aci_choice_log(d))
  expect_true(is.na(quiet$gini_exercise_rate))
})

test_that("choice log rejects unoffered, duplicate and inconsistent trials", {
  d <- .aqt_aci_choice_fixture()
  d$selected[d$option_id=="C"][1] <- TRUE
  # Explicit row indexing ensures the mutation changes the original frame.
  idx <- which(d$option_id=="C")[1]
  d$selected[idx] <- TRUE
  d$choice_s[idx] <- d$trial_s[idx]+1
  expect_error(aqt_aci_choice_log(d),"unavailable option")
  d <- .aqt_aci_choice_fixture()
  j <- which(d$fish_id=="F1" &
             d$trial_id=="trial1" & d$option_id=="B")
  d$selected[j] <- TRUE
  d$choice_s[j] <- 1
  expect_error(aqt_aci_choice_log(d),"Multiple selected options")
  d <- .aqt_aci_choice_fixture()
  d$option_id[1] <- d$option_id[2]
  expect_error(aqt_aci_choice_log(d),"Duplicate option")
  d <- .aqt_aci_choice_fixture()
  d$trial_end_s[1] <- d$trial_end_s[1]+1
  expect_error(aqt_aci_choice_log(d),"fixed tank and event window")
  d <- .aqt_aci_choice_fixture()
  d$offered[1:3] <- FALSE
  d$selected[1:3] <- FALSE
  d$choice_s[1:3] <- NA_real_
  expect_error(aqt_aci_choice_log(d),"at least one offered")
})

test_that("absence of genuine choice is not treated as no agency", {
  d <- .aqt_aci_choice_fixture()
  # F2 is only offered option A, not B or C, in every trial.
  d$offered[d$fish_id=="F2" & d$option_id=="B"] <- FALSE
  d$selected[d$fish_id=="F2"] <- FALSE
  d$choice_s[d$fish_id=="F2"] <- NA_real_
  log <- aqt_aci_choice_log(d)
  summary <- aqt_aci_choice_summary(log)
  expect_equal(summary$per_fish$n_multichoice_opportunities,c(3,0))
  expect_true(is.na(summary$per_fish$multichoice_exercise_rate[2]))
  expect_error(aqt_aci_access_inequality(log),
               "actual multi-option opportunities")
})
