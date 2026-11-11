test_that("2D DTW gives exact known path and diagonal-band costs", {
  a <- aqt_tracks(data.frame(session_id="S",camera_id="TOP",
    track_id="A",time_s=0:2,x=0:2,y=0))
  b <- aqt_tracks(data.frame(session_id="S",camera_id="TOP",
    track_id="B",time_s=0:2,x=0:2,y=0))
  same <- aqt_trajectory_dtw(a,b,window=0)
  expect_equal(same$distance,0)
  expect_equal(same$n_alignment_pairs,3)
  expect_equal(same$path$index_a,1:3)
  shifted <- aqt_tracks(transform(as.data.frame(b),x=1:3))
  apart <- aqt_trajectory_dtw(a,shifted,window=0)
  expect_equal(apart$distance,3)
  expect_equal(apart$mean_step_distance,1)
  expect_error(aqt_trajectory_dtw(a,shifted,window=-1),"window")
})

test_that("DTW enforces dimension, units, observation and sampling contracts", {
  a <- aqt_tracks(data.frame(session_id="S",camera_id="TOP",
    track_id="A",time_s=0:2,x=0:2,y=0))
  long <- aqt_tracks(data.frame(session_id="S",camera_id="TOP",
    track_id="B",time_s=0:4,x=0:4,y=0))
  expect_error(aqt_trajectory_dtw(a,long,window=1),"band")
  metric <- aqt_tracks(as.data.frame(a),units="cm")
  expect_error(aqt_trajectory_dtw(a,metric),"units")
  partial <- aqt_tracks(transform(as.data.frame(a),
                                  observed=c(TRUE,FALSE,TRUE)))
  expect_error(aqt_trajectory_dtw(a,partial),"non-observed")
  expect_error(aqt_trajectory_dtw(a,long,max_gap_s=.5),"gaps")
})

test_that("3D DTW uses actual Z coordinate distances", {
  a <- aqt_tracks(data.frame(session_id="S",camera_id="FUSED3D",
    track_id="A",time_s=c(0,1),x=0,y=0,z=c(0,1)),
    units="cm",coordinate_system="tank")
  b <- aqt_tracks(data.frame(session_id="S",camera_id="FUSED3D",
    track_id="B",time_s=c(0,1),x=0,y=0,z=c(1,2)),
    units="cm",coordinate_system="tank")
  d <- aqt_trajectory_dtw(a,b,window=0)
  expect_equal(d$distance,2)
  expect_equal(d$dimension,3)
  expect_equal(d$units,"cm")
})

test_that("pairwise DTW matrix is symmetric and respects scoped IDs", {
  d <- data.frame(session_id="S",camera_id="TOP",
    track_id=rep(c("A","B","C"),each=3),
    time_s=rep(0:2,3),
    x=c(0:2,1:3,0:2),y=0)
  a <- aqt_tracks(d)
  mat <- aqt_trajectory_dtw_matrix(a,window=0)
  expect_equal(dim(mat),c(3,3))
  expect_true(isSymmetric(mat))
  expect_true(all(diag(mat)==0))
  expect_equal(mat["S/TOP/A","S/TOP/C"],0)
  expect_gt(mat["S/TOP/A","S/TOP/B"],0)
})

test_that("RQA exact recurring positions yield known density and determinism", {
  path <- aqt_tracks(data.frame(session_id="S",camera_id="TOP",
    track_id="A",time_s=0:3,x=c(0,1,0,1),y=0))
  r <- aqt_trajectory_recurrence(path,radius=0,theiler=0,
        min_diagonal=2,min_vertical=2,store_matrix=TRUE)
  expect_equal(r$n_pairs,12)
  expect_equal(r$n_recurrent,4)
  expect_equal(r$recurrence_rate,1/3)
  expect_equal(r$determinism,1)
  expect_equal(r$laminarity,0)
  expect_false(any(diag(r$recurrence_matrix)))
  expect_true(isSymmetric(r$recurrence_matrix))
  expect_error(aqt_trajectory_recurrence(path,radius=-1),"radius")
  expect_error(aqt_trajectory_recurrence(path,radius=1,theiler=-1),
               "Theiler")
})

test_that("finite-grid 2D trajectory PCA captures exact linear shape variance", {
  trajectories <- do.call(rbind,lapply(1:4,function(slope) {
    data.frame(session_id="S",camera_id="TOP",
      track_id=paste0("F",slope),
      time_s=0:4,x=slope*(0:4),y=0)
  }))
  x <- aqt_tracks(trajectories,units="cm",coordinate_system="tank")
  fit <- aqt_trajectory_grid_pca(x,n_grid=5,n_components=2)
  expect_s3_class(fit,"aqt_grid_pca")
  expect_equal(fit$n_paths,4)
  expect_equal(dim(fit$modes),c(5,2,2))
  expect_equal(fit$mean_path[5,"x"],10)
  expect_equal(fit$mean_path[1,"x"],0)
  expect_equal(fit$explained_variance[1],1,tolerance=1e-10)
  expect_equal(sum(fit$scores$PC1),0,tolerance=1e-10)
  expect_gt(stats::sd(fit$scores$PC1),0)
  expect_error(aqt_trajectory_grid_pca(x,n_components=4),
               "rank")
  expect_error(aqt_trajectory_grid_pca(x,n_grid=3),"n_grid")
})

test_that("grid PCA rejects missing gaps and supports 3D paths", {
  x <- aqt_tracks(do.call(rbind,lapply(1:3,function(i) {
    data.frame(session_id="S",camera_id="FUSED3D",
      track_id=paste0("F",i),time_s=0:4,
      x=(0:4)*i,y=(0:4),z=(0:4)*i^2)
  })),units="cm",coordinate_system="tank")
  fit <- aqt_trajectory_grid_pca(x,n_grid=8,n_components=2,
                                  max_gap_s=1)
  expect_equal(fit$dimension,3)
  expect_equal(dim(fit$mean_path),c(8,3))
  expect_equal(colnames(fit$mean_path),c("x","y","z"))
  expect_error(aqt_trajectory_grid_pca(x,n_grid=8,max_gap_s=.5),
               "gaps")
})

test_that("DTW, recurrence and PCA diagnostics render headless PDF", {
  d <- data.frame(session_id="S",camera_id="TOP",
    track_id=rep(c("F1","F2","F3"),each=5),
    time_s=rep(0:4,3),
    x=c(0:4,(0:4)*2,(0:4)*3),
    y=c(0,1,0,1,0,1,0,1,0,1,0,1,0,1,0))
  x <- aqt_tracks(d)
  path <- aqt_tracks(as.data.frame(x[x$track_id=="F1",,drop=FALSE]))
  rec <- aqt_trajectory_recurrence(path,radius=1,store_matrix=TRUE)
  pca <- aqt_trajectory_grid_pca(x,n_grid=6,n_components=1)
  pdf <- tempfile(fileext=".pdf")
  grDevices::pdf(pdf)
  tryCatch({
    expect_s3_class(aqt_plot_recurrence(rec),"aqt_recurrence")
    expect_s3_class(aqt_plot_grid_pca(pca),"aqt_grid_pca")
  },finally=grDevices::dev.off())
  expect_true(file.exists(pdf))
  unlink(pdf)
})
