# Refractive candidate pairing is a numerical hypothesis; no source fish
# is assigned permanent biological identity from paired images.
.cov100_rev_cam <- function(x=0,units="cm") {
 aqt_refractive_camera(K=diag(3),R_c2w=diag(3),
  center=c(x,0,0),plane_point=c(0,0,1),
  plane_normal=c(0,0,1),units=units,n_before=1,n_after=1.333)
}
.cov100_rev_input <- function(cam="A",empty=FALSE,time=0:2) {
 tr<-aqt_tracks(data.frame(session_id="S",camera_id=cam,
       track_id="F",time_s=time,x=rep(0,length(time)),
       y=rep(0,length(time)),observed=TRUE))
 if(empty) {
   raw<-as.data.frame(tr)
   raw$observed<-FALSE;raw$x<-NA_real_;raw$y<-NA_real_
   tr<-aqt_tracks(raw)
 }
 tr
}
test_that("refractive cross-camera hypotheses reject unsurveyed clocks and camera geometry",{
 a<-.cov100_rev_input("A");b<-.cov100_rev_input("B")
 ca<-.cov100_rev_cam(0);cb<-.cov100_rev_cam(2)
 fn<-function(... )aqt_refractive_view_candidates(a,b,ca,cb,...)
 wrong<-aqt_tracks(transform(as.data.frame(a),z=1),
           units="cm",coordinate_system="tank")
 expect_error(aqt_refractive_view_candidates(wrong,b,ca,cb),
              "camera-local 2D image pixel tracks")
 expect_error(aqt_refractive_view_candidates(a,b,list(),cb),
              "two compatible explicitly calibrated")
 expect_error(aqt_refractive_view_candidates(a,b,ca,
              .cov100_rev_cam(2,units="m")),
              "two compatible explicitly calibrated")
 expect_error(fn(max_skew_s=-1),"Invalid positive candidate cap")
 expect_error(fn(max_skew_s=Inf),"Invalid positive candidate cap")
 expect_error(fn(max_ray_separation=-1),"Invalid positive candidate cap")
 expect_error(fn(max_candidates=0),"Invalid positive candidate cap")
 expect_error(fn(max_candidates=1.5),"Invalid positive candidate cap")
 expect_error(aqt_refractive_view_candidates(a,a,ca,cb),
              "Two distinct single-camera")
 expect_error(aqt_refractive_view_candidates(a,b,ca,ca),
              "Distinct optical camera centres")
 none<-aqt_refractive_view_candidates(a,.cov100_rev_input("B",empty=TRUE),
                                     ca,cb)
 expect_equal(nrow(none),0L)
 nonoverlap<-aqt_refractive_view_candidates(a,
     .cov100_rev_input("B",time=10:12),ca,cb,max_skew_s=0)
 expect_equal(nrow(nonoverlap),0L)
 expect_error(fn(max_candidates=2,max_skew_s=0),
              "candidate cap exceeded")
 out<-fn(max_candidates=3,max_skew_s=0)
 expect_equal(nrow(out),3L)
 expect_equal(out$time_skew_s,c(0,0,0))
 expect_false(attr(out,"aqt_biological_identity_certified"))
})
test_that("multicamera fusion refuses unsupported pairwise design and reports missing views",{
 expect_error(aqt_multiview_global_fuse(list()),
              "Expected named distinct-camera")
 expect_error(aqt_multiview_global_fuse(list(B=list())),
              "Expected named distinct-camera")
 empty<-structure(list(tracks_3d=NULL),
                  class="aqt_auto_refractive_pipeline")
 none<-aqt_multiview_global_fuse(list(B=empty))
 expect_null(none$tracks_3d)
 expect_equal(none$matched_camera_count,0L)
 expect_false(none$independently_verified_biological_identity)
 expect_error(aqt_multiview_global_fuse(list(B=empty),
              min_views=3),"Invalid physical 3D consistency")
 expect_error(aqt_multiview_global_fuse(list(B=empty),
              min_views=1),"Invalid physical 3D consistency")
 expect_error(aqt_multiview_global_fuse(list(B=empty),
              max_disagreement=-1),"Invalid physical 3D consistency")
 expect_error(aqt_multiview_global_fuse(list(B=empty),
              max_disagreement=Inf),"Invalid physical 3D consistency")
})
