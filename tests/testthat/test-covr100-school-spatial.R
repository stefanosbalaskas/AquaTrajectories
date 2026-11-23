# Independently check group geometry and occupancy denominators.
.cov100_school <- function(three=FALSE) {
 d <- data.frame(session_id="S",camera_id="C",
   track_id=rep(c("A","B"),each=3),time_s=rep(0:2,2),
   x=c(0,0,0,3,3,3),y=c(0,0,0,4,4,4),observed=TRUE)
 if(three)d$z <- c(rep(0,3),rep(12,3))
 aqt_tracks(d,units="cm",coordinate_system="tank")
}
test_that("school pairwise distances preserve simultaneous fish IDs and units",{
 tr <- .cov100_school()
 expect_error(aqt_group_pairwise_distances(tr,max_pairs=0),"max_pairs")
 expect_error(aqt_group_pairwise_distances(tr,max_pairs=Inf),"max_pairs")
 expect_error(aqt_group_pairwise_distances(tr,max_pairs=1),"Pair cap exceeded")
 p <- aqt_group_pairwise_distances(tr)
 expect_equal(nrow(p),3L)
 expect_equal(p$distance,rep(5,3),tolerance=1e-12)
 expect_identical(attr(p,"aqt_units"),"cm")
 one <- aqt_tracks(as.data.frame(tr)[tr$track_id=="A",,drop=FALSE],
                    units="cm",coordinate_system="tank")
 expect_equal(nrow(aqt_group_pairwise_distances(one)),0)
 none <- aqt_tracks(as.data.frame(tr)[0,,drop=FALSE],
                    units="cm",coordinate_system="tank")
 expect_equal(nrow(aqt_group_pairwise_distances(none)),0)
 spatial <- aqt_group_spatial_summary(tr)
 expect_equal(spatial$radius_gyration,rep(2.5,3),tolerance=1e-12)
 expect_equal(spatial$group_extent,rep(5,3),tolerance=1e-12)
 expect_error(aqt_group_spatial_summary(tr,min_fish=1),"min_fish")
 expect_equal(nrow(aqt_group_spatial_summary(tr,min_fish=3)),0L)
 expect_equal(nrow(aqt_group_spatial_summary(one)),0L)
 expect_equal(nrow(aqt_group_spatial_summary(none)),0L)
 edges <- aqt_group_spatial_edges(tr,radius=5)
 expect_equal(nrow(edges),3L)
 expect_equal(nrow(aqt_group_spatial_edges(tr,radius=4.99)),0)
 expect_error(aqt_group_spatial_edges(tr,radius=0),"radius must")
 three <- aqt_group_pairwise_distances(.cov100_school(TRUE))
 expect_equal(three$distance,rep(13,3),tolerance=1e-12)
 three_summary <- aqt_group_spatial_summary(.cov100_school(TRUE))
 expect_true(all(is.finite(three_summary$centroid_z)))
})
test_that("voxel entropy refuses negative, duplicated and inconsistent denominators",{
 d <- data.frame(session_id="S",camera_id="C",track_id="F",
   ix=c(1,2),iy=1,iz=1,n_samples=c(2,2),n_valid=4,n_outside=0)
 expect_error(aqt_voxel_entropy(data.frame(x=1)),"Expected aqt_voxel")
 expect_equal(nrow(aqt_voxel_entropy(d[0,,drop=FALSE])),0L)
 a <- aqt_voxel_entropy(d)
 expect_equal(a$entropy_bits,1,tolerance=1e-12)
 expect_equal(a$entropy_normalized,1,tolerance=1e-12)
 bad <- d;bad$n_samples[1] <- -1
 expect_error(aqt_voxel_entropy(bad),"nonnegative and finite")
 bad <- d;bad$n_valid[1] <- 5
 expect_error(aqt_voxel_entropy(bad),"Inconsistent voxel occupancy denominators")
 bad <- d;bad$ix[2] <- 1
 expect_error(aqt_voxel_entropy(bad),"Duplicate voxel cells")
 bad <- d;bad$n_samples[2] <- 1
 expect_error(aqt_voxel_entropy(bad),"do not sum to valid observations")
 unobserved <- d;unobserved$n_samples <- 0
 unobserved$n_valid <- 1;unobserved$n_outside <- 1
 e <- aqt_voxel_entropy(unobserved)
 expect_true(is.na(e$entropy_bits))
 expect_true(is.na(e$entropy_normalized))
 singleton <- d[1,,drop=FALSE];singleton$n_valid <- 2
 expect_equal(aqt_voxel_entropy(singleton)$entropy_normalized,0)
 missing_id <- d;missing_id$track_id <- NA_character_
 expect_equal(nrow(aqt_voxel_entropy(missing_id)),1L)
})
