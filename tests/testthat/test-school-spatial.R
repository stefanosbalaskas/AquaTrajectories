test_that("known 2D three-fish geometry matches Euclidean theory", {
  x <- aqt_tracks(data.frame(
    session_id="S1",camera_id="TOP",time_s=0,
    track_id=c("A","B","C"),x=c(0,3,0),y=c(0,4,4)),
    units="cm",coordinate_system="tank")
  pair <- aqt_group_pairwise_distances(x)
  expect_equal(nrow(pair),3)
  expect_equal(sort(pair$distance),c(3,4,5))
  expect_equal(attr(pair,"aqt_units"),"cm")
  g <- aqt_group_spatial_summary(x)
  expect_equal(g$n_visible,3)
  expect_equal(g$centroid_x,1)
  expect_equal(g$centroid_y,8/3,tolerance=1e-12)
  expect_equal(g$radius_gyration,sqrt(50)/3,tolerance=1e-12)
  expect_equal(g$mean_pair_distance,4)
  expect_equal(g$group_extent,5)
  expect_true(is.na(g$centroid_z))
  edges <- aqt_group_spatial_edges(x,radius=4)
  expect_equal(nrow(edges),2)
  expect_equal(sort(edges$distance),c(3,4))
  expect_error(aqt_group_spatial_edges(x,radius=0),"radius")
  expect_error(aqt_group_pairwise_distances(x,max_pairs=2),"cap")
})

test_that("true 3D school geometry includes vertical displacement", {
  x <- aqt_tracks(data.frame(session_id="S1",camera_id="FUSED3D",
    track_id=c("A","B"),time_s=0,
    x=c(0,3),y=c(0,4),z=c(0,12)),
    units="cm",coordinate_system="tank")
  p <- aqt_group_pairwise_distances(x)
  g <- aqt_group_spatial_summary(x)
  expect_equal(p$distance,13)
  expect_equal(g$group_extent,13)
  expect_equal(g$mean_pair_distance,13)
  expect_equal(g$radius_gyration,6.5)
  expect_equal(g$centroid_z,6)
})

test_that("missing or non-observed fish never create artificial school edges", {
  x <- aqt_tracks(data.frame(session_id="S1",camera_id="TOP",
     track_id=c("A","B","C"),time_s=0,
     x=c(0,1,2),y=0,observed=c(TRUE,FALSE,TRUE)))
  p <- aqt_group_pairwise_distances(x)
  expect_equal(nrow(p),1)
  expect_equal(sort(c(p$track_id_1,p$track_id_2)),c("A","C"))
  expect_equal(p$distance,2)
  expect_equal(aqt_group_spatial_summary(x)$n_visible,2)
})

test_that("camera-local identities are never combined between views", {
  x <- aqt_tracks(data.frame(
    session_id="S",camera_id=c("TOP","TOP","SIDE","SIDE"),
    track_id=c("1","2","1","2"),time_s=0,
    x=c(0,3,100,105),y=0))
  out <- aqt_group_pairwise_distances(x)
  expect_equal(nrow(out),2)
  expect_equal(sort(out$distance),c(3,5))
  expect_equal(length(unique(out$camera_id)),2)
})

test_that("voxel entropy uses inside-grid sample frequencies", {
  xyz <- aqt_tracks(data.frame(session_id="S1",camera_id="FUSED3D",
    track_id="F",time_s=0:3,
    x=c(.5,.5,1.5,5),y=.5,z=.5),
    units="cm",coordinate_system="tank")
  vox <- aqt_voxel_occupancy(xyz,
    list(x=c(0,1,2),y=c(0,1),z=c(0,1)),by="fish")
  ent <- aqt_voxel_entropy(vox)
  value <- -(2/3*log2(2/3)+1/3*log2(1/3))
  expect_equal(ent$n_valid,4)
  expect_equal(ent$n_inside,3)
  expect_equal(ent$n_outside,1)
  expect_equal(ent$n_voxels,2)
  expect_equal(ent$entropy_bits,value,tolerance=1e-12)
  expect_equal(ent$entropy_normalized,value,tolerance=1e-12)
  bad <- vox
  bad$n_outside <- 0
  expect_error(aqt_voxel_entropy(bad),"do not sum")
})

test_that("group spatial dynamics produce publication-ready base plots", {
  x <- aqt_tracks(data.frame(session_id="S1",camera_id="TOP",
    track_id=rep(c("A","B"),each=3),
    time_s=rep(0:2,2),
    x=c(0,1,2,3,4,5),y=0))
  g <- aqt_group_spatial_summary(x)
  path <- tempfile(fileext=".pdf")
  grDevices::pdf(path)
  tryCatch({
    plotted <- aqt_plot_school_dynamics(g,"S1","TOP","group_extent")
    expect_equal(nrow(plotted),3)
  },finally=grDevices::dev.off())
  expect_true(file.exists(path))
  unlink(path)
  expect_error(aqt_plot_school_dynamics(g,"S1","MISSING"),
               "No observations")
  expect_error(aqt_plot_school3d(x,"S1","TOP",0),"True calibrated 3D")
})
