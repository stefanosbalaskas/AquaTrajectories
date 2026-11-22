# Direct negative-path oracles for the reviewed, source-scoped two-view
# interfaces. These tests DO NOT certify fish identity or underwater optics.
.cov100_refr_pair <- function() {
 a <- aqt_tracks(data.frame(session_id="S",camera_id="A",
     track_id="fish_a",time_s=0,x=0,y=0))
 b <- aqt_tracks(data.frame(session_id="S",camera_id="B",
     track_id="fish_b",time_s=0,x=-.4,y=0))
 c1 <- aqt_refractive_camera(K=diag(3),R_c2w=diag(3),
     center=c(0,0,0),plane_point=c(0,0,1),
     plane_normal=c(0,0,1),n_before=1,n_after=1,units="cm")
 c2 <- aqt_refractive_camera(K=diag(3),R_c2w=diag(3),
     center=c(2,0,0),plane_point=c(0,0,1),
     plane_normal=c(0,0,1),n_before=1,n_after=1,units="cm")
 match <- data.frame(session_id="S",id_a="fish_a",id_b="fish_b",
        time_a_s=0,time_b_s=0,fish_id="reviewed_fish")
 list(a=a,b=b,c1=c1,c2=c2,matches=match)
}
test_that("refractive reviewed matching refuses unsynchronized, missing or mis-scoped observations", {
 z <- .cov100_refr_pair()
 fn <- function(a=z$a,b=z$b,matched=z$matches,c1=z$c1,c2=z$c2,...)
   aqt_refractive_reconstruct_tracks(a,b,matched,c1,c2,...)
 expect_error(fn(max_skew_s=-.1),"max_skew_s must be")
 expect_error(fn(max_skew_s=Inf),"max_skew_s must be")
 expect_error(fn(max_ray_separation=-1),"max_ray_separation must")
 expect_error(fn(max_ray_separation=NA_real_),"max_ray_separation must")
 expect_error(fn(b=z$a),"exactly one distinct camera")
 expect_error(fn(matched=data.frame(x=1)),"nonempty reviewed")
 expect_error(fn(matched=z$matches[FALSE,,drop=FALSE]),"nonempty reviewed")
 bad <- z$matches;bad$fish_id <- ""
 expect_error(fn(matched=bad),"biological and source IDs must")
 bad <- z$matches;bad$id_b <- NA_character_
 expect_error(fn(matched=bad),"biological and source IDs must")
 bad <- z$matches;bad$time_a_s <- "0"
 expect_error(fn(matched=bad),"timestamps must be finite numeric")
 bad <- z$matches;bad$time_b_s <- Inf
 expect_error(fn(matched=bad),"timestamps must be finite numeric")
 bad <- z$matches;bad$time_b_s <- .5
 expect_error(fn(matched=bad,max_skew_s=.1),"permitted synchronization skew")
 bad <- z$matches;bad$id_a <- "unobserved"
 expect_error(fn(matched=bad),"missing in source camera tracks")
 bad <- as.data.frame(z$b)
 bad$observed[] <- FALSE;bad$x[] <- NA_real_;bad$y[] <- NA_real_
 absent <- aqt_tracks(bad)
 expect_error(fn(b=absent),"No valid reviewed 3D refractive")
 expect_error(aqt_refractive_track_quality(z$a),
              "Expected refractively reconstructed 3D")
 valid <- fn()
 expect_s3_class(valid,"aqt_tracks")
 expect_equal(valid$z,5,tolerance=1e-6)
 expect_false(attr(valid,"aqt_calibration_certified"))
 expect_equal(aqt_refractive_track_quality(valid)$n_valid,1L)
})
.cov100_air_rig <- function(identical=FALSE) {
 pa <- cbind(diag(3),c(0,0,0))
 pb <- cbind(diag(3),c(if(identical)0 else -2,0,0))
 aqt_rig_new(list(A=pa,B=pb),optical_path="air_only")
}
test_that("pinhole candidate finder rejects physical tracks, malformed limits and zero camera baseline",{
 z <- .cov100_refr_pair()
 rig <- .cov100_air_rig()
 fn <- function(a=z$a,b=z$b,r=rig,...)
   aqt_view_candidates(a,b,r,...)
 physical <- aqt_tracks(transform(as.data.frame(z$a),z=1),
       units="cm",coordinate_system="tank")
 expect_error(fn(a=physical),"2D pixel-space camera tracks")
 expect_error(fn(max_skew_s=-1),"max_skew_s must be")
 expect_error(fn(max_skew_s=Inf),"max_skew_s must be")
 expect_error(fn(max_candidates=0),"max_candidates must")
 expect_error(fn(max_candidates=1.2),"max_candidates must")
 expect_error(fn(b=z$a),"distinct single cameras")
 expect_error(fn(r=.cov100_air_rig(identical=TRUE)),
              "Zero-length baseline")
 blank <- as.data.frame(z$b)
 blank$observed[] <- FALSE;blank$x[]<-NA_real_;blank$y[]<-NA_real_
 result <- fn(b=aqt_tracks(blank))
 expect_equal(nrow(result),0L)
 expect_equal(nrow(fn()),1L)
 unshared <- as.data.frame(z$b);unshared$session_id <- "DIFFERENT"
 expect_equal(nrow(fn(b=aqt_tracks(unshared))),0L)
 expect_error(fn(max_candidates=0L),"max_candidates must")
});
