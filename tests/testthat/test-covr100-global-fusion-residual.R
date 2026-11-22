# Synthetic-only source-resolved multiview consistency failures.
# The objects below are software fixtures, not real calibrated XYZ evidence.
.cov100_fused_pipe <- function(reference="A",secondary="B",
                               t=0,world_units="cm") {
  xyz <- aqt_tracks(data.frame(
     session_id="S",camera_id="REFRACTIVE3D",track_id="F",
     time_s=t,x=1,y=2,z=3,observed=TRUE,
     source_camera_a=reference,source_camera_b=secondary,
     source_id_a="FA",source_id_b="FB",
     source_time_a_s=t,ray_separation=.01,
     stringsAsFactors=FALSE),
     units=world_units,coordinate_system="tank")
  structure(list(tracks_3d=xyz),class="aqt_auto_refractive_pipeline")
}
test_that("multiview fusion refuses missing original fish camera/clock provenance",{
  broken <- .cov100_fused_pipe()
  broken$tracks_3d$source_id_a <- NULL
  expect_error(aqt_multiview_global_fuse(list(B=broken)),
               "Missing original paired camera/source/time provenance")
})
test_that("multiview fusion refuses invalid physical underwater ray diagnostics",{
  broken <- .cov100_fused_pipe()
  broken$tracks_3d$ray_separation[1] <- -1
  expect_error(aqt_multiview_global_fuse(list(B=broken)),
               "Invalid original clock and underwater ray diagnostics")
  broken <- .cov100_fused_pipe()
  broken$tracks_3d$source_time_a_s[1] <- Inf
  expect_error(aqt_multiview_global_fuse(list(B=broken)),
               "Invalid original clock and underwater ray diagnostics")
})
test_that("multiview fusion requires common original reference camera and units",{
  b <- .cov100_fused_pipe(reference="A",secondary="B")
  c <- .cov100_fused_pipe(reference="OTHER",secondary="C")
  expect_error(aqt_multiview_global_fuse(list(B=b,C=c)),
               "All source camera pairs must share reference camera and world units")
  c <- .cov100_fused_pipe(reference="A",secondary="C",world_units="m")
  expect_error(aqt_multiview_global_fuse(list(B=b,C=c)),
               "All source camera pairs must share reference camera and world units")
})
test_that("multiview fusion abstains when no reference observation has enough cameras",{
  b <- .cov100_fused_pipe(reference="A",secondary="B",t=0)
  c <- .cov100_fused_pipe(reference="A",secondary="C",t=1)
  result <- aqt_multiview_global_fuse(list(B=b,C=c),min_views=3)
  expect_s3_class(result,"aqt_multiview_global_fusion")
  expect_null(result$tracks_3d)
  expect_equal(nrow(result$per_observation),0)
  expect_equal(result$matched_camera_count,3L)
  expect_false(result$independently_verified_biological_identity)
})
