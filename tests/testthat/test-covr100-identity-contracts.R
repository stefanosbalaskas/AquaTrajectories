# Camera-local identity scenario error paths, including impossible
# cross-tank assertions. No automatic reidentification is claimed.

.cov100_identity_fixture <- function() {
  x <- aqt_tracks(data.frame(session_id="S",camera_id="C",
       track_id=rep(c("A","B"),each=3),time_s=rep(0:2,2),
       x=c(0,1,2,10,11,12),y=0,tank_id="T",treatment="control"),
       units="cm",coordinate_system="tank")
  e <- data.frame(session_id="S",camera_id="C",
       track_a="A",track_b="B",at_s=1,probability_swap=.5)
  list(tracks=x,event=e)
}

test_that("candidate identity switches require explicit scope, finite probability and coherent draws", {
  d <- .cov100_identity_fixture()
  x <- d$tracks;e <- d$event
  expect_error(aqt_identity_switch_scenarios(x,list()),"Candidate events require")
  expect_error(aqt_identity_switch_scenarios(x,e,draws=0),"Invalid draws")
  expect_error(aqt_identity_switch_scenarios(x,e,draws=1.2),"Invalid draws")
  expect_error(aqt_identity_switch_scenarios(x,e,draws=1e7),"Invalid draws")
  expect_error(aqt_identity_switch_scenarios(x,e,seed=-1),"seed must")
  expect_error(aqt_identity_switch_scenarios(x,e,seed=1.5),"seed must")
  bad <- e;bad$track_a <- ""
  expect_error(aqt_identity_switch_scenarios(x,bad),"scope and IDs")
  bad <- e;bad$session_id <- NA_character_
  expect_error(aqt_identity_switch_scenarios(x,bad),"scope and IDs")
  bad <- e;bad$at_s <- Inf
  expect_error(aqt_identity_switch_scenarios(x,bad),"Switch times must")
  bad <- e;bad$probability_swap <- NA_real_
  expect_error(aqt_identity_switch_scenarios(x,bad),"Switch times must")
  bad <- e;bad$probability_swap <- -.1
  expect_error(aqt_identity_switch_scenarios(x,bad),"Switch times must")
  bad <- e;bad$track_b <- bad$track_a
  expect_error(aqt_identity_switch_scenarios(x,bad),"two distinct track labels")
  bad <- e;bad$at_s <- 5
  expect_error(aqt_identity_switch_scenarios(x,bad),"present future scoped")
  bad <- e;bad$track_a <- "NOT_PRESENT"
  expect_error(aqt_identity_switch_scenarios(x,bad),"present future scoped")
  double <- rbind(e,transform(e,track_a="B",track_b="A"))
  expect_error(aqt_identity_switch_scenarios(x,double),"Simultaneous switches")
  altered <- as.data.frame(x)
  altered$tank_id[altered$track_id=="B"] <- "DIFFERENT"
  other_tank <- aqt_tracks(altered,units="cm",coordinate_system="tank")
  expect_error(aqt_identity_switch_scenarios(other_tank,e),"between tanks")
  valid <- aqt_identity_switch_scenarios(x,e,draws=10,seed=33)
  expect_s3_class(valid,"aqt_identity_scenarios")
  expect_identical(dim(valid$decisions),c(10L,1L))
  expect_false(valid$probability_calibrated)
})

test_that("empty candidate set leaves labels unchanged and carries zero draws events", {
  d <- .cov100_identity_fixture()
  e <- d$event[FALSE,,drop=FALSE]
  s <- aqt_identity_switch_scenarios(d$tracks,e,draws=4,seed=41)
  expect_identical(dim(s$decisions),c(4L,0L))
  expect_error(aqt_identity_draw(list()),"Expected an aqt_identity_scenarios")
  expect_error(aqt_identity_draw(s,draw=0),"Invalid identity scenario")
  expect_error(aqt_identity_draw(s,draw=5),"Invalid identity scenario")
  invalid <- s
  invalid$decisions <- c(TRUE,FALSE)
  expect_error(aqt_identity_draw(invalid),"Expected an aqt_identity_scenarios")
  normal <- aqt_identity_draw(s,draw=2)
  expect_identical(normal$track_id,d$tracks$track_id)
  expect_true(all(!normal$assignment_changed))
  expect_identical(attr(normal,"aqt_identity_draw"),2L)
  path <- aqt_identity_path_sensitivity(s,max_gap_s=1)
  expect_true(is.data.frame(path))
  expect_identical(sort(unique(path$draw)),1:4)
})

test_that("event and tank-sensitivity identities do not invent independent observations", {
  d <- .cov100_identity_fixture()
  expect_error(aqt_identity_path_sensitivity(list()),"Expected identity scenarios")
  expect_error(aqt_identity_event_sensitivity(list(),data.frame()),"Expected identity scenarios")
  s <- aqt_identity_switch_scenarios(d$tracks,d$event,draws=2,seed=42)
  unrelated <- data.frame(session_id="unobserved",event_id="E",
            start_s=1,end_s=1)
  out <- aqt_identity_event_sensitivity(s,unrelated,
             windows=list(baseline=c(-1,0),response=c(0,1)))
  expect_true(is.data.frame(out))
  expect_equal(nrow(out),0L)
  expect_error(aqt_identity_tank_sensitivity(list(),unrelated),
               "must include tank_id and treatment")
  expect_error(aqt_identity_tank_sensitivity(s,unrelated),
               "No estimable identity event epochs")
  no_treatment <- as.data.frame(d$tracks)
  no_treatment$treatment <- NULL
  x <- aqt_tracks(no_treatment,units="cm",coordinate_system="tank")
  without <- aqt_identity_switch_scenarios(x,d$event,draws=2)
  expect_error(aqt_identity_tank_sensitivity(without,unrelated),
               "must include tank_id and treatment")
})
