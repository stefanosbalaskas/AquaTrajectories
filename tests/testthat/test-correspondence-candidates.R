test_that("stereo candidate hypotheses preserve ambiguity and need human review", {
  P1 <- cbind(diag(3),c(0,0,0))
  P2 <- cbind(diag(3),c(-1,0,0))
  rig <- aqt_rig_new(list(TOP=P1,SIDE=P2),
                     units="cm",optical_path="air_only")
  a <- aqt_tracks(data.frame(session_id="S1",camera_id="TOP",
    track_id=c("a1","a2"),time_s=0,
    x=c(.5,.75),y=c(.25,.25)))
  b <- aqt_tracks(data.frame(session_id="S1",camera_id="SIDE",
    track_id=c("b7","b8"),time_s=0,
    x=c(.25,.5),y=c(.25,.25)))
  candidates <- aqt_view_candidates(a,b,rig,max_skew_s=0)
  expect_equal(nrow(candidates),4)
  expect_true(all(c("candidate_id","reprojection_rmse_px","valid") %in%
                    names(candidates)))
  ranked <- aqt_candidate_rank(candidates,max_reprojection_px=1)
  expect_true(any(ranked$n_eligible_a>1))
  # The correct pairs are established externally, not chosen by geometry.
  i <- which(candidates$id_a=="a1" & candidates$id_b=="b7")
  j <- which(candidates$id_a=="a2" & candidates$id_b=="b8")
  review <- data.frame(candidate_id=candidates$candidate_id[c(i,j)],
    fish_id=c("F1","F2"),reviewer="observerA",
    reason="known calibration fixtures")
  pairs <- aqt_correspondences_from_review(candidates,review)
  xyz <- aqt_reconstruct_3d(a,b,pairs,rig,max_skew_s=0)
  expect_equal(xyz$x,c(2,3),tolerance=1e-8)
  expect_equal(xyz$z,c(4,4),tolerance=1e-8)
  expect_equal(sort(xyz$track_id),c("F1","F2"))
  duplicated_source <- transform(review,fish_id=c("F1","F2"))
  duplicated_source$candidate_id[2] <- candidates$candidate_id[
    which(candidates$id_a=="a2" & candidates$id_b=="b7")]
  expect_error(aqt_correspondences_from_review(candidates,duplicated_source),
               "multiple fish")
  expect_error(aqt_correspondences_from_review(candidates,
    transform(review,candidate_id=c("missing",review$candidate_id[2]))),
    "missing")
})

test_that("candidate generation respects time skew, world assumptions and caps", {
  P1 <- cbind(diag(3),c(0,0,0))
  P2 <- cbind(diag(3),c(-1,0,0))
  r <- aqt_rig_new(list(TOP=P1,SIDE=P2),optical_path="air_only")
  a <- aqt_tracks(data.frame(session_id="S1",camera_id="TOP",
    track_id=c("A","B"),time_s=c(0,1),x=c(.5,.75),y=.25))
  b <- aqt_tracks(data.frame(session_id="S1",camera_id="SIDE",
    track_id=c("C","D"),time_s=c(.02,1.02),x=c(.25,.5),y=.25))
  near <- aqt_view_candidates(a,b,r,max_skew_s=.025)
  expect_equal(nrow(near),2)
  far <- aqt_view_candidates(a,b,r,max_skew_s=.001)
  expect_equal(nrow(far),0)
  expect_error(aqt_view_candidates(a,b,r,max_skew_s=2,
                                   max_candidates=1),
               "cap")
  unknown <- aqt_rig_new(list(TOP=P1,SIDE=P2))
  expect_error(aqt_view_candidates(a,b,unknown),"unknown")
})

test_that("time-window indexing is inclusive for equal source timestamps", {
  P1 <- cbind(diag(3),c(0,0,0))
  P2 <- cbind(diag(3),c(-1,0,0))
  rig <- aqt_rig_new(list(TOP=P1,SIDE=P2),optical_path="air_only")
  a <- aqt_tracks(data.frame(session_id="S",camera_id="TOP",
    track_id="a",time_s=0,x=.5,y=.25))
  b <- aqt_tracks(data.frame(session_id="S",camera_id="SIDE",
    track_id=c("b1","b2","b3"),time_s=0,x=c(.25,.3,.4),y=.25))
  candidates <- aqt_view_candidates(a,b,rig,max_skew_s=0)
  expect_equal(nrow(candidates),3)
  expect_equal(sort(candidates$id_b),c("b1","b2","b3"))
})
