# Paired physical-pulse clock diagnostics use synthetic, perfectly
# synchronized marker labels, never claims of measured shutter timing.

.cov100_pulses <- function() {
  p <- paste0("P",1:6)
  x <- expand.grid(camera_id=c("A","B"),marker_id=p,
       KEEP.OUT.ATTRS=FALSE,stringsAsFactors=FALSE)
  x$session_id <- "S"
  x$time_s <- match(x$marker_id,p)-1 + ifelse(x$camera_id=="B",2,0)
  x
}
.cov100_fit_clock <- function(markers=.cov100_pulses()) {
  aqt_sync_holdout_fit(markers,"A",paste0("P",1:4),paste0("P",5:6))
}

test_that("holdout clock fitting rejects malformed pulses and hidden overlaps", {
  m <- .cov100_pulses()
  expect_error(aqt_sync_holdout_fit(data.frame(x=1),"A",
        paste0("P",1:4),paste0("P",5:6)),"Expected nonempty")
  bad <- m;bad$session_id[1] <- ""
  expect_error(.cov100_fit_clock(bad),"Missing session")
  bad <- m;bad$time_s[1] <- Inf
  expect_error(.cov100_fit_clock(bad),"timestamps must be finite")
  bad <- m;bad$time_s <- as.character(bad$time_s)
  expect_error(.cov100_fit_clock(bad),"timestamps must be finite")
  bad <- m;bad$marker_id[bad$camera_id=="B"][2] <- "P1"
  expect_error(.cov100_fit_clock(bad),"Duplicate pulse ID")
  expect_error(aqt_sync_holdout_fit(m,"",paste0("P",1:4),paste0("P",5:6)),
        "Specify one reference camera")
  expect_error(aqt_sync_holdout_fit(m,"A",c("P1","P1","P3","P4"),c("P5","P6")),
        "unique and complete")
  expect_error(aqt_sync_holdout_fit(m,"A",paste0("P",1:3),paste0("P",5:6)),
        "Need >=4 training")
  expect_error(aqt_sync_holdout_fit(m,"A",paste0("P",1:4),c("P4","P5")),
        "Need >=4 training")
  expect_error(aqt_sync_holdout_fit(m,"A",paste0("P",1:4),paste0("P",5:6),
              max_holdout_error_s=0),"prespecified positive")
  expect_error(aqt_sync_holdout_fit(m,"UNLISTED",paste0("P",1:4),
              paste0("P",5:6)),"Each session must contain reference")
  expect_error(.cov100_fit_clock(m[m$camera_id=="A",,drop=FALSE]),
        "Each session must contain reference")
  bad <- m[!(m$camera_id=="A" & m$marker_id=="P3"),,drop=FALSE]
  expect_error(.cov100_fit_clock(bad),"Reference camera is missing")
  bad <- m[!(m$camera_id=="B" & m$marker_id=="P3"),,drop=FALSE]
  expect_error(.cov100_fit_clock(bad),"is missing a required sync pulse")
  bad <- m
  bad$time_s[bad$camera_id=="A" & bad$marker_id=="P2"] <- 0
  expect_error(.cov100_fit_clock(bad),"unique in time")
  bad <- m
  bad$time_s[bad$camera_id=="B" & bad$marker_id=="P2"] <- 2
  expect_error(.cov100_fit_clock(bad),"increase in physical order")
})

test_that("holdout timing retains provenance and rejects failed or missing transforms", {
  fit <- .cov100_fit_clock()
  expect_s3_class(fit,"aqt_clock_holdout")
  expect_true(all(fit$fits$within_tolerance))
  expect_false(fit$camera_timing_certified)
  tr <- aqt_tracks(data.frame(session_id="S",camera_id="B",track_id="01",
       time_s=c(2,2.5,3),x=c(1,2,3),y=c(3,4,5)))
  expect_error(aqt_sync_holdout_apply(tr,list()),"Expected aqt_clock_holdout")
  expect_error(aqt_sync_holdout_apply(tr,fit,require_tolerance=NA),
        "single logical")
  expect_error(aqt_sync_holdout_apply(tr,fit,max_extrapolation_s=-1),
        "finite nonnegative")
  bad <- fit
  bad$fits <- rbind(fit$fits,fit$fits[1,,drop=FALSE])
  expect_error(aqt_sync_holdout_apply(tr,bad),"Duplicate affine")
  extra <- as.data.frame(tr)
  extra$camera_id <- "C"
  expect_error(aqt_sync_holdout_apply(aqt_tracks(extra),fit),
        "No heldout timing fit")
  bad <- fit
  bad$fits$within_tolerance[bad$fits$camera_id=="B"] <- FALSE
  expect_error(aqt_sync_holdout_apply(tr,bad),"fails heldout synchronization")
  outside <- as.data.frame(tr);outside$time_s[] <- c(10,11,12)
  expect_error(aqt_sync_holdout_apply(aqt_tracks(outside),fit),
        "pulse support/extrapolation")
  already <- as.data.frame(tr);already$time_raw_s <- already$time_s
  expect_error(aqt_sync_holdout_apply(aqt_tracks(already),fit),
        "prevent double clock mapping")
  aligned <- aqt_sync_holdout_apply(tr,fit)
  expect_equal(aligned$time_raw_s,c(2,2.5,3))
  expect_equal(aligned$time_s,c(0,.5,1),tolerance=1e-10)
  expect_true(all(aligned$clock_within_tolerance))
  expect_false(attr(aligned,"aqt_clock_pulse_verification"))
})

test_that("heldout clock mapping rejects a nonpositive regression slope",{
 testthat::with_mocked_bindings({
   expect_error(.cov100_fit_clock(),
                "Non-identifiable or invalid positive camera clock mapping")
 },.aqt_sync_holdout_lm=function(formula) structure(
   list(coefficients=c("(Intercept)"=0,"time"=-1)),
   class="lm"),.package="aquaTrajectories")
})
