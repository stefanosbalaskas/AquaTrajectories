# Synthetic camera geometry validates software; no real underwater accuracy.
.auto_stereo_fixture <- function() {
  K <- diag(c(100,100,1))
  R <- diag(3)
  first <- aqt_refractive_camera(K,R,c(0,0,0),
    c(0,0,1),c(0,0,1),n_before=1,n_after=1,units="cm")
  second <- aqt_refractive_camera(K,R,c(1,0,0),
    c(0,0,1),c(0,0,1),n_before=1,n_after=1,units="cm")
  targets <- data.frame(fish=c("f1","f2"),
    x=c(.2,.4),y=c(0,1),z=c(5,5))
  build <- function(camera,centre,offset) {
    d <- do.call(rbind,lapply(seq_len(nrow(targets)),function(j) {
      p <- targets[j,]
      data.frame(session_id="synthetic_tank1",camera_id=camera,
        track_id=p$fish,time_s=c(0,.1,.2)+offset,
        x=rep((p$x-centre)*100/p$z,3),
        y=rep(p$y*100/p$z,3),stringsAsFactors=FALSE)
    }))
    aqt_tracks(d,units="px",coordinate_system="image")
  }
  list(a=build("TOP",0,0),b=build("SIDE",1,.005),
    ca=first,cb=second,targets=targets)
}

test_that("refractive auto candidates construct real 2D source-ID hypotheses",{
  f <- .auto_stereo_fixture()
  candidates <- aqt_refractive_view_candidates(f$a,f$b,f$ca,f$cb,
    max_skew_s=.01,max_ray_separation=.05)
  expect_s3_class(candidates,"data.frame")
  expect_true(nrow(candidates)>=6)
  expect_true(sum(candidates$valid)>=6)
  expect_false(attr(candidates,"aqt_biological_identity_certified"))
  expect_false(attr(candidates,"aqt_clock_hardware_sync_certified"))
  expect_error(aqt_refractive_view_candidates(f$a,f$b,f$ca,f$cb,
    max_skew_s=.01,max_candidates=1),"candidate cap")
  expect_error(aqt_refractive_view_candidates(f$a,f$a,f$ca,f$ca),
               "distinct single-camera")
})

test_that("stable identity assignment respects full-track one-to-one and source timestamps",{
  f <- .auto_stereo_fixture()
  result <- aqt_auto_refractive_pipeline(f$a,f$b,f$ca,f$cb,
    max_skew_s=.01,max_ray_separation=.05,
    min_support=3,ambiguity_margin=.005)
  expect_s3_class(result,"aqt_auto_refractive_pipeline")
  expect_equal(result$status,"automatic_geometric_3d_hypotheses_reconstructed")
  expect_equal(nrow(result$association$links),2L)
  expect_equal(nrow(result$association$correspondences),6L)
  expect_s3_class(result$tracks_3d,"aqt_tracks")
  expect_true(all(result$tracks_3d$observed))
  expect_equal(nrow(result$tracks_3d),6L)
  expect_true(max(abs(result$tracks_3d$z-5))<1e-5)
  expect_true(max(result$tracks_3d$ray_separation)<1e-5)
  expect_false(result$fish_biological_identity_certified)
  expect_false(result$physical_xyz_accuracy_certified)
  expect_false(result$clock_hardware_synchronization_certified)
  expect_true(attr(result$tracks_3d,"aqt_auto_fish_id_provisional"))
})

test_that("unresolvable geometric ties correctly abstain instead of inventing fish IDs",{
  d <- data.frame(candidate_id=paste0("p",1:6),
    session_id="s",camera_a="top",camera_b="side",
    id_a="a1",id_b=rep(c("b1","b2"),each=3),
    time_a_s=rep(c(0,.1,.2),2),time_b_s=rep(c(0,.1,.2),2),
    time_skew_s=0,x=1,y=1,z=5,ray_separation=0,
    valid=TRUE)
  result <- aqt_crossview_auto_associate(d,
    min_support=3,max_error=.5,ambiguity_margin=.01)
  expect_equal(nrow(result$links),0L)
  expect_equal(nrow(result$correspondences),0L)
  expect_gte(result$n_ambiguous_abstentions,1L)
  expect_false(result$independent_biological_identity_certified)
  d$ray_separation[4:6] <- .2
  different <- aqt_crossview_auto_associate(d,
    min_support=3,max_error=.5,ambiguity_margin=.01)
  expect_equal(nrow(different$links),1L)
  expect_equal(different$links$id_b,"b1")
  expect_equal(nrow(different$correspondences),3L)
})

test_that("missing observations do not produce fabricated stereo positions",{
  f <- .auto_stereo_fixture()
  other <- aqt_tracks(transform(as.data.frame(f$b),
      time_s=time_s+10),units="px",coordinate_system="image")
  result <- aqt_auto_refractive_pipeline(f$a,other,f$ca,f$cb,
      max_skew_s=.01,max_ray_separation=.05,min_support=1)
  expect_null(result$tracks_3d)
  expect_equal(result$status,"no_unambiguous_crossview_track_pairs")
  expect_false(result$fish_biological_identity_certified)
})
