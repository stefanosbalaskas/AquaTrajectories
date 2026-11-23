# Explicit pinhole-camera contracts with fully synthetic known-correspondence
# projections. Neither air-only pinhole calibration nor biological identity
# is independently certified by these tests.

.cov100_rig <- function(air=TRUE) {
  pa <- cbind(diag(3),c(0,0,0))
  pb <- cbind(diag(3),c(-2,0,0))
  aqt_rig_new(list(A=pa,B=pb),optical_path=if(air)"air_only" else "unknown")
}
.cov100_views <- function() {
  a <- aqt_tracks(data.frame(session_id="S",camera_id="A",
       track_id="a",time_s=0,x=0,y=0))
  b <- aqt_tracks(data.frame(session_id="S",camera_id="B",
       track_id="b",time_s=0,x=-.4,y=0))
  matches <- data.frame(session_id="S",id_a="a",id_b="b",
      time_a_s=0,time_b_s=0,fish_id="fish")
  list(a=a,b=b,matched=matches)
}

test_that("camera rigs reject ambiguous units, noninvertible and malformed projections", {
  pa <- cbind(diag(3),c(0,0,0))
  pb <- cbind(diag(3),c(-2,0,0))
  expect_error(aqt_rig_new(list(A=pa)),"named list of two")
  expect_error(aqt_rig_new(list(pa,pb)),"named list of two")
  expect_error(aqt_rig_new(list(A=pa,A=pb)),"named list of two")
  expect_error(aqt_rig_new(list(A=pa,B=pb),units="pixels"),"World units must")
  bad <- pb;bad[1,1] <- NA_real_
  expect_error(aqt_rig_new(list(A=pa,B=bad)),"finite numeric 3x4")
  bad <- pb;bad[1,1] <- "x"
  expect_error(aqt_rig_new(list(A=pa,B=bad)),"finite numeric 3x4")
  bad <- pb[,1:3]
  expect_error(aqt_rig_new(list(A=pa,B=bad)),"finite numeric 3x4")
  bad <- pb;bad[,2] <- bad[,1]
  expect_error(aqt_rig_new(list(A=pa,B=bad)),"invertible")
  rig <- .cov100_rig()
  expect_s3_class(rig,"aqt_rig")
  expect_error(aqt_rig_validate(list()),"unqualified aqt_rig")
  corrupted <- rig;corrupted$calibration_qualified <- TRUE
  expect_error(aqt_rig_validate(corrupted),"unqualified aqt_rig")
  expect_true(aqt_rig_validate(rig))
  expect_equal(aqt_rig_baseline(rig,"A","B"),2,tolerance=1e-12)
  expect_error(aqt_rig_baseline(rig,"A","A"),"Distinct rig camera")
  expect_error(aqt_rig_baseline(rig,"A","missing"),"Distinct rig camera")
})

test_that("pinhole projection enforces exact numeric XYZ and declared optical medium", {
  rig <- .cov100_rig()
  xyz <- matrix(c(0,0,5,1,1,5),ncol=3,byrow=TRUE)
  a <- aqt_rig_project(rig,xyz,"A")
  expect_equal(a$x,c(0,.2),tolerance=1e-12)
  expect_equal(a$y,c(0,.2),tolerance=1e-12)
  expect_true(all(a$valid))
  expect_error(aqt_rig_project(rig,xyz,"missing"),"Unknown camera_id")
  expect_error(aqt_rig_project(rig,matrix(1:4,ncol=2),"A"),
               "numeric n-by-3")
  bad <- xyz;bad[1,1] <- Inf
  expect_error(aqt_rig_project(rig,bad,"A"),"XYZ points must be finite")
  expect_error(aqt_rig_project(.cov100_rig(FALSE),xyz,"A"),
               "explicitly declared air_only")
  on_axis <- aqt_rig_project(rig,matrix(c(1,2,0),ncol=3),"A")
  expect_false(on_axis$valid)
  expect_true(is.na(on_axis$x))
})

test_that("known correspondence reconstruction refuses missing identities and unqualified water optics", {
  d <- .cov100_views();rig <- .cov100_rig()
  expect_error(aqt_reconstruct_3d(aqt_tracks(transform(
       as.data.frame(d$a),z=1),coordinate_system="tank"),
       d$b,d$matched,rig),"2D pixel-space")
  expect_error(aqt_reconstruct_3d(d$a,d$b,d$matched,.cov100_rig(FALSE)),
               "Refraction or unknown optical paths")
  expect_error(aqt_reconstruct_3d(d$a,d$b,d$matched,rig,max_skew_s=-1),
               "max_skew_s")
  bad_view <- as.data.frame(d$b)
  bad_view$camera_id <- "A"
  b_same <- aqt_tracks(bad_view)
  expect_error(aqt_reconstruct_3d(d$a,b_same,d$matched,rig),
               "one distinct camera")
  pb <- rig$projections$A
  zero_baseline <- aqt_rig_new(list(A=pb,B=pb),optical_path="air_only")
  expect_error(aqt_reconstruct_3d(d$a,d$b,d$matched,zero_baseline),
               "Degenerate camera baseline")
  expect_error(aqt_reconstruct_3d(d$a,d$b,data.frame(x=1),rig),
               "nonempty explicit")
  bad <- d$matched;bad$fish_id <- ""
  expect_error(aqt_reconstruct_3d(d$a,d$b,bad,rig),
               "identities must be explicit")
  bad <- d$matched;bad$time_b_s <- Inf
  expect_error(aqt_reconstruct_3d(d$a,d$b,bad,rig),
               "times must be finite")
  bad <- d$matched;bad$time_b_s <- .5
  expect_error(aqt_reconstruct_3d(d$a,d$b,bad,rig,max_skew_s=.1),
               "permitted synchronization skew")
  bad <- d$matched;bad$id_b <- "absent"
  expect_error(aqt_reconstruct_3d(d$a,d$b,bad,rig),
               "absent from their camera tracks")
  bad <- rbind(d$matched,d$matched)
  expect_error(aqt_reconstruct_3d(d$a,d$b,bad,rig),
               "assigned to multiple fish")
  absent <- as.data.frame(d$b)
  absent$x <- NA_real_;absent$y <- NA_real_;absent$observed <- FALSE
  expect_error(aqt_reconstruct_3d(d$a,aqt_tracks(absent),d$matched,rig),
               "No valid 3D reconstructed positions")
  expect_error(aqt_reconstruction_quality(d$a),"stereo QC fields")
})

test_that("synthetic noiseless known point triangulates with explicit pinhole rig", {
  d <- .cov100_views()
  rig <- .cov100_rig()
  out <- aqt_reconstruct_3d(d$a,d$b,d$matched,rig)
  expect_s3_class(out,"aqt_tracks")
  expect_equal(out$x,0,tolerance=1e-6)
  expect_equal(out$y,0,tolerance=1e-6)
  expect_equal(out$z,5,tolerance=1e-5)
  expect_false(attr(out,"aqt_rig")$calibration_qualified)
  qc <- aqt_reconstruction_quality(out)
  expect_equal(qc$n_reconstructed,1L)
  expect_equal(qc$max_time_skew_s,0)
})
