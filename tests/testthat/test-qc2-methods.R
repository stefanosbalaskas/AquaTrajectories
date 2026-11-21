# Deeper synthetic independent numerical comparisons; no real biological oracle.

test_that("sparse FPCA intake respects affine clock changes and missingness", {
  set.seed(744)
  base <- seq(0,1,length.out=16)
  df <- do.call(rbind,lapply(seq_len(9L),function(k) {
    missing <- (seq_along(base)+2*k) %% 7L==0L
    y <- sin(2*pi*base)+k/10
    data.frame(session_id="S",camera_id="TOP",track_id=paste0("fish",k),
      time_s=base+(k %% 3)*.001,
      x=ifelse(missing,NA_real_,y),
      y=ifelse(missing,NA_real_,2*y),
      observed=!missing)
  }))
  tr <- aqt_tracks(df,units="cm",coordinate_system="tank")
  base_input <- aqt_sparse_fpca_input(tr,time_axis="relative",min_points=8L)
  changed <- df
  changed$time_s <- 7+3*changed$time_s
  modified <- aqt_tracks(changed,units="cm",coordinate_system="tank")
  new_input <- aqt_sparse_fpca_input(modified,
                                     time_axis="relative",min_points=8L)
  expect_equal(base_input$Ly,new_input$Ly,tolerance=1e-12)
  expect_equal(base_input$Lt,new_input$Lt,tolerance=1e-12)
  expect_identical(base_input$scope$n_observed,new_input$scope$n_observed)
  expect_identical(base_input$missingness_explicit,TRUE)
  expect_equal(sum(base_input$scope$n_total),nrow(df))
  audit <- aqt_sparse_fpca_design_audit(base_input,bins=12L)
  for(j in seq_len(nrow(audit))) {
    bin <- j
    edge <- seq(min(unlist(base_input$Lt)),
                max(unlist(base_input$Lt)),length.out=13L)
    actual <- sum(vapply(base_input$Lt,function(tt)
      any(findInterval(tt,edge,rightmost.closed=TRUE,
                       all.inside=TRUE)==bin),logical(1L)))
    expect_equal(audit$n_curves[j],actual)
  }
})

test_that("3D group nearest neighbor, centroid and polarization match independent loops", {
  set.seed(203)
  n <- 7L
  base <- matrix(stats::runif(n*3L,-5,5),nrow=n,ncol=3L)
  d <- do.call(rbind,lapply(seq_len(n),function(i)
    data.frame(session_id="S",camera_id="C",track_id=paste0("fish",i),
      time_s=c(0,1,2),x=base[i,1]+c(0,1,2),
      y=base[i,2]+c(0,2,4),z=base[i,3]+c(0,3,6),
      observed=TRUE)))
  tr <- aqt_tracks(d,units="m",coordinate_system="tank")
  out <- aqt_group_metrics(tr,max_gap_s=1.1)
  expect_equal(nrow(out),3L)
  for(t in 0:2) {
    ix <- out$time_s==t
    xyz <- base+matrix(rep(c(t,2*t,3*t),each=n),
                       nrow=n,ncol=3L)
    dist_ref <- numeric(n)
    for(i in seq_len(n)) {
      candidates <- numeric()
      for(j in seq_len(n)) if(j!=i)
        candidates <- c(candidates,sqrt(sum((xyz[i,]-xyz[j,])^2)))
      dist_ref[i] <- min(candidates)
    }
    expect_equal(out$mean_nearest_neighbor[ix],
                 mean(dist_ref),tolerance=1e-10)
    expect_equal(unname(c(out$centroid_x[ix],
                          out$centroid_y[ix],out$centroid_z[ix])),
                 unname(colMeans(xyz)),tolerance=1e-10)
  }
  expect_true(is.na(out$polarization[1L]))
  expect_equal(out$polarization[-1L],c(1,1),tolerance=1e-10)
})
