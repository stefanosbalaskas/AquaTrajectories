# PRIORITY A -- independent numerical-reference qualification.
# These are deterministic mathematical fixtures, NOT biological accuracy tests.
# The comparison oracles use base/stats R, closed-form geometry, or exhaustive
# enumeration rather than delegating to the corresponding AquaTrajectories
# estimators. Reference values cannot certify the input observations.

test_that("camera clock transformation agrees with independent stats::lm", {
  markers <- rbind(
    data.frame(camera_id="MASTER",marker_id=letters[1:4],
               time_s=c(1,3,5,8)),
    data.frame(camera_id="SIDE",marker_id=letters[1:4],
               time_s=c(0,2,4,7)))
  fit <- aqt_sync_fit(markers,"MASTER")
  side <- fit[fit$camera_id=="SIDE",]
  oracle <- stats::lm(c(1,3,5,8) ~ c(0,2,4,7))
  expect_equal(unname(c(side$intercept_s,side$slope)),
               unname(stats::coef(oracle)),tolerance=1e-12)
  expect_equal(side$rmse_s,sqrt(mean(stats::residuals(oracle)^2)),
               tolerance=1e-12)
  expect_true(side$drift_identifiable)
  orig <- aqt_tracks(data.frame(session_id="S",camera_id="SIDE",
    track_id="0001",time_s=0:2,x=c(0,1,2),y=c(0,1,2)))
  corrected <- aqt_sync_apply(orig,fit)
  expect_equal(corrected$time_s,unname(stats::coef(oracle)[1] +
               stats::coef(oracle)[2]*orig$time_s),tolerance=1e-12)
  expect_identical(corrected$track_id,orig$track_id)
  expect_identical(attr(corrected,"aqt_units"),"px")
  expect_error(aqt_sync_apply(orig,fit[fit$camera_id=="MASTER",]),
               "Missing clock transform")
})

test_that("grid PCA matches independently assembled stats::prcomp design", {
  t <- 0:4
  slope <- matrix(c(1,0,2,0,0,1,2,2,3,1),ncol=2,byrow=TRUE)
  fish <- do.call(rbind,lapply(seq_len(nrow(slope)),function(i)
    data.frame(session_id="S",camera_id="TOP",track_id=paste0("F",i),
      time_s=t,x=slope[i,1]*t,y=slope[i,2]*t)))
  tracks <- aqt_tracks(fish,units="cm",coordinate_system="tank")
  got <- aqt_trajectory_grid_pca(tracks,n_grid=5,n_components=2,
                                  origin="start",max_gap_s=1)
  reference_matrix <- t(vapply(seq_len(nrow(slope)),function(i)
    c(slope[i,1]*t,slope[i,2]*t),numeric(10)))
  reference <- stats::prcomp(reference_matrix,center=TRUE,scale.=FALSE)
  expected_var <- reference$sdev[1:2]^2/sum(reference$sdev^2)
  expect_equal(got$explained_variance,unname(expected_var),tolerance=1e-12)
  expect_equal(as.vector(got$mean_path),unname(reference$center),
               tolerance=1e-12)
  # PCA signs are arbitrary; scores are compared after absolute value.
  expect_equal(abs(as.matrix(got$scores[,c("PC1","PC2")])),
               unname(abs(reference$x[,1:2])),tolerance=1e-10,
               ignore_attr=TRUE)
  bad <- tracks
  bad$observed[2] <- FALSE
  expect_error(aqt_trajectory_grid_pca(bad,n_grid=5),
               "missing|non-observed")
  expect_error(aqt_trajectory_grid_pca(tracks,n_grid=5,max_gap_s=.5),
               "gaps")
  figure <- tempfile(fileext=".pdf")
  grDevices::pdf(figure)
  tryCatch(expect_s3_class(aqt_plot_grid_pca(got),"aqt_grid_pca"),
           finally=grDevices::dev.off())
  expect_gt(file.info(figure)$size,1000)
})

test_that("DTW has an independently enumerated global optimum", {
  make <- function(id,xx) aqt_tracks(data.frame(session_id="S",
    camera_id="TOP",track_id=id,time_s=seq_along(xx)-1,
    x=xx,y=rep(0,length(xx))),units="cm",coordinate_system="tank")
  a <- make("A",c(0,1,3))
  b <- make("B",c(0,2,2,4))
  # Exhaustively enumerate all admissible alignment paths -- not DTW DP.
  brute <- function(i,j) {
    local <- abs(a$x[i]-b$x[j])
    if(i==nrow(a) && j==nrow(b)) return(local)
    candidates <- numeric()
    if(i<nrow(a)) candidates <- c(candidates,brute(i+1,j))
    if(j<nrow(b)) candidates <- c(candidates,brute(i,j+1))
    if(i<nrow(a) && j<nrow(b))
      candidates <- c(candidates,brute(i+1,j+1))
    local+min(candidates)
  }
  got <- aqt_trajectory_dtw(a,b)
  expect_equal(got$distance,brute(1,1),tolerance=1e-12)
  expect_equal(got$mean_step_distance,
               got$distance/got$n_alignment_pairs,tolerance=1e-12)
  expect_false(got$aligned_clocks)
  expect_error(aqt_trajectory_dtw(a,b,window=0),"band")
  converted <- aqt_tracks(as.data.frame(a),units="m",
                         coordinate_system="tank")
  expect_error(aqt_trajectory_dtw(converted,b),"units")
})

test_that("recurrence agrees with externally computed distance comparisons", {
  pos <- matrix(c(0,0,1,0,0,1,0,0,1,0),ncol=2,byrow=TRUE)
  path <- aqt_tracks(data.frame(session_id="S",camera_id="TOP",
    track_id="F",time_s=0:4,x=pos[,1],y=pos[,2]))
  for(theiler in c(0L,1L,2L)) {
    oracle <- matrix(FALSE,5,5)
    for(i in 1:5) for(j in 1:5)
      oracle[i,j] <- abs(i-j)>theiler &&
        sum((pos[i,]-pos[j,])^2)<=1
    got <- aqt_trajectory_recurrence(path,radius=1,theiler=theiler,
                   store_matrix=TRUE)
    expect_equal(got$recurrence_matrix,oracle)
    expect_equal(got$n_pairs,sum(abs(outer(1:5,1:5,"-"))>theiler))
    expect_equal(got$n_recurrent,sum(oracle))
    expect_equal(got$recurrence_rate,mean(oracle[
      abs(outer(1:5,1:5,"-"))>theiler]),tolerance=1e-12)
  }
  pdf <- tempfile(fileext=".pdf")
  grDevices::pdf(pdf)
  tryCatch(expect_s3_class(aqt_plot_recurrence(got),"aqt_recurrence"),
           finally=grDevices::dev.off())
  expect_gt(file.info(pdf)$size,1000)
})

test_that("2D/3D geometry, unit conversion and invalid samples match formulas", {
  points <- data.frame(session_id="S",camera_id="TOP",time_s=0,
    track_id=c("A","B","C","D"),x=c(0,3,0,100),
    y=c(0,0,4,100),observed=c(TRUE,TRUE,TRUE,FALSE))
  track <- aqt_tracks(points,units="cm",coordinate_system="tank")
  g <- aqt_group_spatial_summary(track)
  expected <- as.matrix(stats::dist(as.matrix(points[1:3,c("x","y")])))
  expect_equal(g$mean_pair_distance,mean(expected[upper.tri(expected)]))
  expect_equal(g$group_extent,max(expected))
  expect_equal(g$centroid_x,mean(points$x[1:3]))
  expect_equal(g$centroid_y,mean(points$y[1:3]))
  expect_equal(g$radius_gyration,sqrt(mean(rowSums(sweep(
    as.matrix(points[1:3,c("x","y")]),2,colMeans(
    points[1:3,c("x","y")]),"-")^2))),tolerance=1e-12)
  expect_equal(nrow(aqt_group_spatial_edges(track,radius=4)),2L)
  expect_identical(attr(aqt_group_spatial_edges(track,4),"aqt_units"),"cm")
  pixel <- aqt_tracks(transform(points[1:3,],x=x*10,y=y*10),
                      units="px",coordinate_system="image")
  scaled <- aqt_scale_calibrate(pixel,pixels_per_cm=10)
  expect_equal(scaled$x,points$x[1:3])
  expect_equal(scaled$y,points$y[1:3])
  expect_equal(scaled$x_px,pixel$x)
  expect_identical(attr(scaled,"aqt_units"),"cm")
  expect_error(aqt_scale_calibrate(track,10),"2D pixel-space")
  expect_error(aqt_group_pairwise_distances(track,max_pairs=2),"Pair cap")
})

test_that("voxel sample counts and Shannon entropy agree with table/log2", {
  d <- data.frame(session_id="S",camera_id="FUSED",track_id="007",
    time_s=0:4,x=c(.25,.25,1.25,1.25,5),y=.25,z=.25,
    observed=TRUE)
  tracks <- aqt_tracks(d,units="cm",coordinate_system="tank")
  breaks <- list(x=c(0,1,2),y=c(0,1,2),z=c(0,1,2))
  vox <- aqt_voxel_occupancy(tracks,breaks,by="fish")
  expect_equal(sum(vox$n_samples),4)
  expect_equal(unique(vox$n_valid),5)
  expect_equal(unique(vox$n_outside),1)
  expect_equal(sort(vox$n_samples[vox$n_samples>0]),c(2L,2L))
  expect_equal(sort(unique(vox$sample_fraction[vox$n_samples>0])),.4)
  ent <- aqt_voxel_entropy(vox)
  expected <- -sum(c(.5,.5)*log2(c(.5,.5)))
  expect_equal(ent$entropy_bits,expected,tolerance=1e-12)
  expect_equal(ent$entropy_normalized,expected/log2(8),tolerance=1e-12)
  expect_equal(ent$n_inside,4)
  bad <- vox
  bad$n_valid <- bad$n_valid+1
  expect_error(aqt_voxel_entropy(bad),"counts do not sum")
})

test_that("event windows match base-R mean and trapezoid time integration", {
  d <- data.frame(session_id="S",camera_id="TOP",track_id="F",
    time_s=c(0,1,2,3,4),speed=c(0,2,4,6,8),
    observed=c(TRUE,TRUE,TRUE,TRUE,TRUE))
  events <- data.frame(session_id="S",event_id="feeding",
                       start_s=2,end_s=2)
  windows <- list(before=c(-2,0),after=c(0,2))
  m <- aqt_event_epoch_summary(d,events,"speed",windows=windows,
    min_points=2,estimator="sample_mean")
  w <- aqt_event_epoch_summary(d,events,"speed",windows=windows,
    min_points=2,estimator="time_weighted",max_gap_s=1.1)
  expect_equal(m$value,c(mean(c(0,2)),mean(c(4,6,8))),
               tolerance=1e-12)
  expect_equal(w$value,c((0+2)/2,(4+6+8)/3*1),tolerance=1e-12)
  # Weighted mean of linear 4,6,8 over t=2..4 is 6.
  expect_equal(w$value[2],6,tolerance=1e-12)
  gapped <- d
  gapped$observed[4] <- FALSE
  result <- aqt_event_epoch_summary(gapped,events,"speed",
    windows=windows,min_points=2,estimator="time_weighted",max_gap_s=1.1)
  expect_true(is.na(result$value[result$epoch=="after"]))
  expect_equal(result$observed_span_s[result$epoch=="after"],0)
  expect_error(aqt_event_epoch_summary(d,events,"speed",
      windows=list(a=c(-1,1),b=c(0,2))),"overlap")
})

test_that("between-tank contrast matches independent tank-only bootstrap", {
  design <- expand.grid(tank_id=c("C1","C2","C3","T1","T2","T3"),
    epoch=c("baseline","response"),stringsAsFactors=FALSE)
  design$treatment <- ifelse(substr(design$tank_id,1,1)=="C",
                              "control","treatment")
  design$value <- c(1,2,3,1,2,3, 2,3,4,4,6,5)
  a <- aqt_tank_event_contrast(design,draws=150L,seed=55L)
  baseline <- design$value[design$epoch=="baseline"]
  response <- design$value[design$epoch=="response"]
  change <- response-baseline
  expected <- mean(change[4:6])-mean(change[1:3])
  expect_equal(a$estimate,expected,tolerance=1e-12)
  expect_equal(sort(a$per_tank$change),sort(change),tolerance=1e-12)
  # Reproduce the stated bootstrap using base sample() over tank changes.
  set.seed(55)
  ctrl <- change[1:3]; trt <- change[4:6]
  oracle <- replicate(150L,mean(sample(trt,3,replace=TRUE))-
                       mean(sample(ctrl,3,replace=TRUE)))
  q <- unname(stats::quantile(oracle,c(.025,.975),names=FALSE))
  expect_equal(c(a$lower,a$upper),q,tolerance=1e-12)
  expect_false(a$causal_identification)
  bad <- design
  bad$treatment[1] <- "treatment"
  expect_error(aqt_design_audit(bad),"varies within tank")
})

test_that("HMM posteriors and likelihood agree with exhaustive state sequences", {
  y <- c(-.1,.3,2.5)
  data <- data.frame(session_id="S",camera_id="TOP",track_id="F",
                     time_s=0:2,speed=y,observed=TRUE)
  mu <- c(0,3); sd <- c(1,1)
  transition <- matrix(c(.85,.15,.2,.8),2,2,byrow=TRUE)
  initial <- c(.6,.4)
  got <- aqt_hmm_decode(data,state_means=mu,state_sds=sd,
           transition=transition,initial=initial,max_gap_s=1.1,
           min_segment=3L)
  paths <- expand.grid(s1=1:2,s2=1:2,s3=1:2)
  probability <- apply(paths,1L,function(s) {
    initial[s[1]]*stats::dnorm(y[1],mu[s[1]],sd[s[1]])*
      transition[s[1],s[2]]*stats::dnorm(y[2],mu[s[2]],sd[s[2]])*
      transition[s[2],s[3]]*stats::dnorm(y[3],mu[s[3]],sd[s[3]])
  })
  total <- sum(probability)
  expect_equal(attr(got,"aqt_hmm_total_loglik"),log(total),
               tolerance=1e-10)
  for(i in 1:3) for(s in 1:2) {
    reference <- sum(probability[paths[[paste0("s",i)]]==s])/total
    expect_equal(got[[paste0("hmm_p",s)]][i],reference,
                 tolerance=1e-10)
  }
  expect_equal(got$hmm_state,as.integer(paths[which.max(probability),]),
               ignore_attr=TRUE)
  expect_false(attr(got,"aqt_hmm_welfare_certified"))
  data$observed[2] <- FALSE
  expect_error(aqt_hmm_decode(data,state_means=mu,state_sds=sd,
               transition=transition,max_gap_s=1.1,min_segment=3L),
               "No contiguous")
})
