test_that("known-parameter HMM recovers a two-state fish step per scoped fish", {
  n <- 24L
  x <- data.frame(
    session_id="S",camera_id="TOP",
    track_id=rep(c("F1","F2"),each=n),
    tank_id=rep(c("T1","T2"),each=n),
    treatment=rep(c("control","treated"),each=n),
    time_s=rep(seq(0,23)/10,2),
    speed=c(rep(0,12),rep(10,12),rep(10,12),rep(0,12)))
  transition <- matrix(c(.95,.05,.05,.95),2,2,byrow=TRUE)
  d <- aqt_hmm_decode(
    x,state_means=c(0,10),state_sds=c(.5,.5),
    transition=transition,initial=c(.5,.5),
    state_labels=c("slow","fast"),max_gap_s=.11)
  expect_s3_class(d,"aqt_hmm_states")
  expect_equal(nrow(d),48)
  expect_true(all(d$hmm_usable))
  expect_equal(d$hmm_state[d$track_id=="F1"],
               c(rep(1L,12),rep(2L,12)))
  expect_equal(d$hmm_state[d$track_id=="F2"],
               c(rep(2L,12),rep(1L,12)))
  expect_equal(d$hmm_state_label[d$track_id=="F1"][13],"fast")
  expect_equal(rowSums(d[,c("hmm_p1","hmm_p2")]),rep(1,48),
               tolerance=1e-10)
  expect_true(all(d$hmm_entropy>=0))
  expect_equal(length(unique(d$hmm_segment)),2)
  expect_true(is.finite(attr(d,"aqt_hmm_total_loglik")))
  expect_false(attr(d,"aqt_hmm_model")$parameters_estimated_from_data)
  expect_false(attr(d,"aqt_hmm_welfare_certified"))
  summary <- aqt_hmm_state_summary(d)
  expect_equal(nrow(summary),4)
  expect_true(all(summary$n_switches_total==1L))
  expect_true(all(summary$n_segments==1L))
  expect_true(all(summary$n_input==24L))
  expect_true(all(summary$n_modelled==24L))
  expect_true(all(summary$fraction_of_modelled_samples==.5))
  expect_equal(sort(unique(summary$tank_id)),c("T1","T2"))
  expect_false(attr(summary,"aqt_hmm_independent_tank_test"))
})

test_that("missing frames, long gaps and undersized runs are never imputed", {
  t <- c(1:9,100:103,200:201)
  d <- data.frame(
    session_id="S",camera_id="SIDE",track_id="A",tank_id="Tank1",
    time_s=t,speed=rep(1,length(t)),observed=rep(TRUE,length(t)))
  d$observed[5] <- FALSE
  d$speed[5] <- 100
  decoded <- aqt_hmm_decode(
    d,state_means=c(1,8),state_sds=c(1,1),
    transition=matrix(c(.9,.1,.1,.9),2,2,byrow=TRUE),
    max_gap_s=1.01,min_segment=3)
  expect_equal(sum(!is.na(decoded$hmm_state)),12)
  expect_equal(length(unique(stats::na.omit(decoded$hmm_segment))),3)
  expect_true(all(is.na(decoded$hmm_state[c(5,14,15)])))
  expect_true(all(is.na(decoded$hmm_p1[c(5,14,15)])))
  expect_true(decoded$hmm_usable[14])
  expect_false(decoded$hmm_usable[5])
  expect_true(all(decoded$hmm_state[!is.na(decoded$hmm_state)]==1))
  summary <- aqt_hmm_state_summary(decoded)
  expect_equal(summary$n_input,rep(15,2))
  expect_equal(summary$n_observed,rep(14,2))
  expect_equal(summary$n_modelled,rep(12,2))
  expect_equal(summary$n_unclassified,rep(3,2))
  expect_equal(summary$n_segments,rep(3,2))
  expect_equal(summary$n_switches_total,rep(0,2))
})

test_that("same tracker label in independent tanks does not merge sequences", {
  x <- data.frame(session_id="S",camera_id="TOP",track_id="same",
    tank_id=rep(c("T1","T2"),each=5),
    time_s=rep(1:5,2),speed=c(rep(0,5),rep(9,5)))
  d <- aqt_hmm_decode(
    x,state_means=c(0,9),state_sds=c(1,1),
    transition=matrix(c(.9,.1,.1,.9),2,2,byrow=TRUE),
    max_gap_s=1.1)
  expect_equal(length(unique(d$hmm_segment)),2)
  expect_true(all(d$hmm_state[d$tank_id=="T1"]==1))
  expect_true(all(d$hmm_state[d$tank_id=="T2"]==2))
})

test_that("invalid HMM statistical parameters and track inputs fail closed", {
  x <- data.frame(session_id="S",camera_id="TOP",
    track_id="F",time_s=1:5,speed=1:5)
  trans <- matrix(c(.9,.1,.1,.9),2,2,byrow=TRUE)
  good <- function(d=x,...) aqt_hmm_decode(
    d,state_means=c(0,4),state_sds=c(1,1),
    transition=trans,...)
  expect_error(good(state_labels=c("same","same")),"distinct")
  expect_error(good(initial=c(.5,.3)),"summing to one")
  expect_error(good(max_gap_s=Inf),"finite positive")
  expect_error(good(min_segment=1),"integer")
  expect_error(aqt_hmm_decode(x,state_means=c(4,0),
    state_sds=c(1,1),transition=trans),"increasing")
  expect_error(aqt_hmm_decode(x,state_means=c(0,4),
    state_sds=c(1,0),transition=trans),"strictly positive")
  expect_error(aqt_hmm_decode(x,state_means=c(0,4),
    state_sds=c(1,1),transition=matrix(1,2,2)),"row-stochastic")
  expect_error(good(transform(x,time_s=c(1,2,2,4,5))),
               "Duplicate/nonincreasing")
  expect_error(good(transform(x,observed=c(TRUE,TRUE,NA,TRUE,TRUE))),
               "complete logical")
  expect_error(good(transform(x,speed=c(1,2,Inf,4,5))),
               "without infinities")
  expect_error(good(transform(x,tank_id=c("A","A","A",NA,"A"))),
               "IDs must be complete")
  short <- x[1:2,,drop=FALSE]
  expect_error(good(short,min_segment=3),"No contiguous")
  expect_error(aqt_hmm_state_summary(x),"Expected aqt_hmm_states")
})

test_that("zero-probability HMM transitions remain numerical and audited", {
  x <- data.frame(session_id="S",camera_id="TOP",
    track_id="F",time_s=0:4,speed=rep(0,5))
  d <- aqt_hmm_decode(
    x,state_means=c(0,10),state_sds=c(1,1),
    transition=diag(2),initial=c(1,0),max_gap_s=1.1)
  expect_true(all(d$hmm_state==1))
  expect_equal(d$hmm_p1,rep(1,5),tolerance=1e-12)
  expect_equal(d$hmm_p2,rep(0,5),tolerance=1e-12)
  expect_equal(d$hmm_entropy,rep(0,5),tolerance=1e-12)
})
