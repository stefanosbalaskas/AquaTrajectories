# Numerical Validation 2.0: independent closed-form / exhaustive / external
# reference methods for the core scientific contracts. All inputs are synthetic.
# NEVER interpret these tests as biological accuracy or metrology certification.

test_that("NV2_KINEMATICS: manual finite differences, symmetry, gap and input failures", {
  d <- data.frame(session_id="S",camera_id="C",track_id="007",
                  time_s=c(0,.5,1,2,3),x=c(0,3,3,7,8),
                  y=c(0,4,5,8,8),z=c(0,0,2,2,2),
                  observed=c(TRUE,TRUE,TRUE,TRUE,FALSE))
  tr <- aqt_tracks(d,units="cm",coordinate_system="tank")
  got <- aqt_kinematics(tr,max_gap_s=.75)
  xyz <- as.matrix(d[,c("x","y","z")])
  distances <- vapply(2:5,function(i)
    sqrt(sum((xyz[i,]-xyz[i-1L,])^2)),numeric(1L))
  expect_equal(got$step_distance[2:3],distances[1:2],tolerance=1e-12)
  expect_true(all(is.na(got$step_distance[c(1,4,5)])))
  expect_equal(got$speed[2:3],distances[1:2]/.5,tolerance=1e-12)
  expect_equal(aqt_path_summary(tr,max_gap_s=.75)$path_length,
               sum(distances[1:2]),tolerance=1e-12)
  moved <- d
  moved$x <- moved$x+101; moved$y <- moved$y-55; moved$z <- moved$z+17
  rotated <- moved
  rotated$x <- -moved$y
  rotated$y <- moved$x
  expect_equal(aqt_kinematics(aqt_tracks(rotated,"cm","tank"),.75)$step_distance,
               got$step_distance,tolerance=1e-12)
  bad <- d; bad$time_s[3] <- bad$time_s[2]
  expect_error(aqt_tracks(bad,"cm","tank"),"Duplicate time")
  expect_error(aqt_kinematics(tr,max_gap_s=0),"positive")
})

test_that("NV2_GROUP: exhaustive centroid, nearest neighbor and polarization", {
  xyz <- matrix(c(0,0,0,3,0,0,0,4,0,3,4,0),byrow=TRUE,ncol=3)
  make <- function(offset=0,names=c("A","B","C","D")) {
    do.call(rbind,lapply(seq_len(nrow(xyz)),function(i)
      data.frame(session_id="S",camera_id="C",track_id=names[i],
       time_s=0:2,x=xyz[i,1]+offset+0:2,
       y=xyz[i,2]+2*(0:2),z=xyz[i,3]+3*(0:2),observed=TRUE)))
  }
  tr <- aqt_tracks(make(),units="cm",coordinate_system="tank")
  g <- aqt_group_metrics(tr,max_gap_s=1.01)
  dist <- function(a,b)sqrt(sum((a-b)^2))
  nearest <- vapply(seq_len(4),function(i)
    min(vapply(setdiff(seq_len(4),i),function(j)
      dist(xyz[i,],xyz[j,]),numeric(1L))),numeric(1L))
  expect_equal(g$mean_nearest_neighbor,rep(mean(nearest),3),tolerance=1e-12)
  expect_equal(g$centroid_x,colMeans(xyz)[1]+0:2,tolerance=1e-12)
  expect_equal(g$centroid_y,colMeans(xyz)[2]+2*(0:2),tolerance=1e-12)
  expect_true(is.na(g$polarization[1]))
  expect_equal(g$polarization[-1],c(1,1),tolerance=1e-12)
  moved <- aqt_group_metrics(aqt_tracks(make(offset=15,
          names=c("W","X","Y","Z")),"cm","tank"),1.01)
  expect_equal(moved$mean_nearest_neighbor,g$mean_nearest_neighbor)
  expect_equal(moved$centroid_x,g$centroid_x+15)
  expect_error(aqt_group_spatial_summary(tr,min_fish=1),"min_fish")
})

test_that("NV2_DTW: exhaustive discrete path oracle, symmetry, scaling and failures", {
  make <- function(id,x) aqt_tracks(data.frame(
    session_id="S",camera_id="C",track_id=id,
    time_s=seq_along(x)-1L,x=x,y=0*x),
    units="cm",coordinate_system="tank")
  a <- make("A",c(0,2,4))
  b <- make("B",c(1,1,3,5))
  enumerate <- function(i,j) {
    local <- abs(a$x[i]-b$x[j])
    if(i==nrow(a)&&j==nrow(b))return(local)
    next_costs <- numeric()
    if(i<nrow(a))next_costs <- c(next_costs,enumerate(i+1,j))
    if(j<nrow(b))next_costs <- c(next_costs,enumerate(i,j+1))
    if(i<nrow(a)&&j<nrow(b))
      next_costs <- c(next_costs,enumerate(i+1,j+1))
    local+min(next_costs)
  }
  val <- aqt_trajectory_dtw(a,b)
  expect_equal(val$distance,enumerate(1,1),tolerance=1e-12)
  expect_equal(aqt_trajectory_dtw(b,a)$distance,val$distance,
               tolerance=1e-12)
  shifted <- make("B",b$x+12)
  a_shift <- make("A",a$x+12)
  expect_equal(aqt_trajectory_dtw(a_shift,shifted)$distance,val$distance,
               tolerance=1e-12)
  expect_equal(aqt_trajectory_dtw(make("A",2*a$x),make("B",2*b$x))$distance,
               2*val$distance,tolerance=1e-12)
  expect_error(aqt_trajectory_dtw(a,b,window=0),"band")
  invalid <- b;invalid$observed[2] <- FALSE
  expect_error(aqt_trajectory_dtw(a,invalid),"missing|non-observed")
})

test_that("NV2_RECURRENCE: independent RQA line enumeration, isometry and failures", {
  xx <- c(0,1,2,1,0,1,2)
  a <- aqt_tracks(data.frame(session_id="S",camera_id="C",
     track_id="F",time_s=0:6,x=xx,y=rep(0,7)),
     units="cm",coordinate_system="tank")
  got <- aqt_trajectory_recurrence(a,radius=1,theiler=1,
     min_diagonal=2,min_vertical=2,store_matrix=TRUE)
  mat <- matrix(FALSE,length(xx),length(xx))
  for(i in seq_along(xx))for(j in seq_along(xx)) {
    mat[i,j] <- abs(i-j)>1 && abs(xx[i]-xx[j])<=1
  }
  expect_identical(unname(got$recurrence_matrix),unname(mat))
  # This oracle counts runs by explicit boolean position scans, not rle().
  count_in_long_runs <- function(bits,minlen=2L) {
    tally<-0L;len<-0L
    for(v in c(bits,FALSE)){
      if(v) len<-len+1L
      else {if(len>=minlen)tally<-tally+len;len<-0L}
    }
    tally
  }
  diag_total <- 0
  for(offset in -(length(xx)-1):(length(xx)-1)) {
    pairs <- which(row(mat)+offset==col(mat),arr.ind=TRUE)
    if(nrow(pairs))diag_total <- diag_total+
      count_in_long_runs(mat[pairs])
  }
  vert_total <- sum(vapply(seq_len(ncol(mat)),function(j)
       count_in_long_runs(mat[,j]),numeric(1L)))
  expect_equal(got$n_recurrent,sum(mat))
  expect_equal(got$recurrence_rate,sum(mat)/sum(abs(outer(
      seq_along(xx),seq_along(xx),"-"))>1),tolerance=1e-12)
  expect_equal(got$determinism,diag_total/sum(mat),tolerance=1e-12)
  expect_equal(got$laminarity,vert_total/sum(mat),tolerance=1e-12)
  shifted<-a;shifted$x <- shifted$x+100;shifted$y <- shifted$y-60
  expect_equal(aqt_trajectory_recurrence(shifted,1)$recurrence_rate,
               got$recurrence_rate)
  expect_error(aqt_trajectory_recurrence(a,radius=-1),"nonnegative")
  invalid<-a;invalid$observed[2]<-FALSE
  expect_error(aqt_trajectory_recurrence(invalid,1),"missing|non-observed")
})

test_that("NV2_HMM: exhaustive joint enumeration, additive invariance, bad model", {
  y<-c(-.3,0.6,2.0,3.2)
  initial<-c(.6,.4)
  tm<-matrix(c(.85,.15,.12,.88),nrow=2,byrow=TRUE)
  mu<-c(0,3);sds<-c(.8,1.1)
  d<-data.frame(session_id="S",camera_id="C",track_id="F",
                time_s=0:3,speed=y,observed=TRUE)
  got<-aqt_hmm_decode(d,state_means=mu,state_sds=sds,
                      transition=tm,initial=initial,
                      max_gap_s=1.1,min_segment=3)
  seqs<-expand.grid(rep(list(1:2),4))
  prob<-apply(seqs,1,function(k){
    z<-initial[k[1]]*stats::dnorm(y[1],mu[k[1]],sds[k[1]])
    for(i in 2:4)z<-z*tm[k[i-1],k[i]]*
       stats::dnorm(y[i],mu[k[i]],sds[k[i]])
    z
  })
  total<-sum(prob)
  expect_equal(attr(got,"aqt_hmm_total_loglik"),log(total),
               tolerance=1e-11)
  for(i in 1:4)for(state in 1:2)
    expect_equal(got[[paste0("hmm_p",state)]][i],
       sum(prob[seqs[[i]]==state])/total,tolerance=1e-11)
  moved<-d;moved$speed<-moved$speed+24
  comparison<-aqt_hmm_decode(moved,state_means=mu+24,state_sds=sds,
                            transition=tm,initial=initial,
                            max_gap_s=1.1,min_segment=3)
  expect_equal(comparison[,c("hmm_p1","hmm_p2")],
               got[,c("hmm_p1","hmm_p2")],tolerance=1e-11)
  bad_tm<-tm;bad_tm[1,1]<-.9
  expect_error(aqt_hmm_decode(d,state_means=mu,state_sds=sds,
       transition=bad_tm),"row-stochastic")
  d$observed[2]<-FALSE
  expect_error(aqt_hmm_decode(d,state_means=mu,state_sds=sds,
       transition=tm,max_gap_s=1.1,min_segment=3),"No contiguous")
})

test_that("NV2_FPCA: independent dense SVD, sign invariant and invalid curves", {
  t<-seq(0,1,length.out=7)
  slopes<-rbind(c(1,0),c(0,2),c(1,2),c(2,1),c(3,1),c(1,3))
  df<-do.call(rbind,lapply(seq_len(nrow(slopes)),function(i)
    data.frame(session_id="S",camera_id="C",track_id=paste0("F",i),
      time_s=t,x=slopes[i,1]*t,y=slopes[i,2]*t,observed=TRUE)))
  tr<-aqt_tracks(df,"cm","tank")
  got<-aqt_trajectory_grid_pca(tr,n_grid=7,n_components=2,
                               origin="start",max_gap_s=.2)
  # Base SVD of a separately constructed design matrix, not package PCA.
  M<-t(vapply(seq_len(nrow(slopes)),function(i)
      c(slopes[i,1]*t,slopes[i,2]*t),numeric(14)))
  centered<-sweep(M,2L,colMeans(M),"-")
  sv<-base::svd(centered)
  evals<-sv$d^2/(nrow(M)-1L)
  expect_equal(got$explained_variance,evals[1:2]/sum(evals),
               tolerance=1e-11)
  expect_equal(as.vector(got$mean_path),colMeans(M),
               tolerance=1e-11)
  expect_equal(abs(as.matrix(got$scores[,c("PC1","PC2")])),
               abs(sweep(sv$u[,1:2,drop=FALSE],2,sv$d[1:2],"*")),
               tolerance=1e-10,ignore_attr=TRUE)
  shifted<-df;shifted$x<-shifted$x+50;shifted$y<-shifted$y-8
  ref<-aqt_trajectory_grid_pca(aqt_tracks(shifted,"cm","tank"),
                 n_grid=7,n_components=2,origin="start",max_gap_s=.2)
  expect_equal(got$explained_variance,ref$explained_variance,
               tolerance=1e-10)
  broken<-tr;broken$observed[2]<-FALSE
  expect_error(aqt_trajectory_grid_pca(broken,n_grid=7),"missing|non-observed")
})

test_that("NV2_HIERARCHICAL: independent tank difference-of-differences, relabel and fail", {
  skip_if_not_installed("nlme")
  set.seed(23)
  tanks<-paste0("T",seq_len(12))
  d<-do.call(rbind,lapply(seq_along(tanks),function(i)
    do.call(rbind,lapply(1:3,function(f){
      baseline<-5+0.17*i+0.31*f+.1*sin(i*f)
      change<-.25+if(i>6).8 else 0
      change<-change+.16*cos(i+f)
      data.frame(tank_id=tanks[i],camera_id="C",
        track_id=paste0("F",f),
        treatment=if(i<=6)"control" else "treatment",
        epoch=c("baseline","response"),
        value=c(baseline,baseline+change))
    }))))
  prepared<-aqt_hierarchical_event_prepare(d)
  wrapped<-aqt_hierarchical_event_fit(prepared,method="ML")
  oracle<-nlme::lme(fixed=value~treatment*epoch,
     random=~1|tank_id/fish_unit,
     data=as.data.frame(prepared),method="ML",
     na.action=stats::na.fail,
     control=nlme::lmeControl(returnObject=FALSE))
  expect_equal(unname(nlme::fixef(wrapped$model)),
               unname(nlme::fixef(oracle)),tolerance=1e-10)
  expect_equal(as.numeric(stats::logLik(wrapped$model)),
               as.numeric(stats::logLik(oracle)),tolerance=1e-9)
  fish<-split(seq_len(nrow(prepared)),
      paste(prepared$tank_id,prepared$fish_unit))
  change<-vapply(fish,function(idx){
      x<-prepared[idx,,drop=FALSE]
      x$value[x$epoch=="response"]-x$value[x$epoch=="baseline"]
  },numeric(1L))
  arm<-vapply(fish,function(idx)
      as.character(prepared$treatment[idx[1L]]),character(1L))
  contrast<-mean(change[arm=="treatment"])-mean(change[arm=="control"])
  expect_equal(unname(nlme::fixef(wrapped$model)[4]),contrast,
               tolerance=1e-8)
  relabel<-d;relabel$track_id<-paste0("SPEC-",relabel$track_id)
  ref<-aqt_hierarchical_event_fit(aqt_hierarchical_event_prepare(relabel),
                                  method="ML")
  expect_equal(unname(nlme::fixef(ref$model)),
               unname(nlme::fixef(wrapped$model)),tolerance=1e-8)
  invalid<-d[!d$tank_id %in% c("T2","T3","T4","T5","T6"),]
  expect_error(aqt_hierarchical_event_prepare(invalid),
               ">=2 independent tanks")
})

test_that("NV2_UNCERTAINTY: zero-noise exactness, RNG isolation, quantile and fail", {
  x<-aqt_tracks(data.frame(session_id="S",camera_id="C",track_id="F",
      time_s=0:5,x=c(0,1,2,NA,4,5),y=c(0,1,0,NA,1,0),
      observed=c(TRUE,TRUE,TRUE,FALSE,TRUE,TRUE)),
      units="cm",coordinate_system="tank")
  set.seed(251);rng<-.Random.seed
  scenarios<-aqt_trajectory_ensemble(x,sigma=0,systematic_sd=0,
                  draws=24,seed=11,max_gap_s=1.1)
  expect_identical(.Random.seed,rng)
  expect_true(all(is.na(scenarios$positions[4,,])))
  for(k in c(1,9,24)){
    tr<-aqt_ensemble_tracks(scenarios,k)
    expect_equal(tr$x,x$x)
    expect_equal(tr$y,x$y)
  }
  values<-data.frame(session_id="S",camera_id="C",track_id="F",
      draw=1:5,value=c(1,2,3,4,5))
  s<-aqt_ensemble_summarize(values,value_col="value",level=.8)
  expect_equal(s$conditional_mean,mean(1:5))
  expect_equal(s$conditional_sd,stats::sd(1:5))
  expect_equal(c(s$lower,s$upper),
      unname(stats::quantile(1:5,c(.1,.9))),tolerance=1e-12)
  expect_identical(attr(s,"aqt_interval_type"),
                   "conditional measurement sensitivity")
  expect_error(aqt_trajectory_ensemble(x,rho=1,draws=24),"rho")
  repeat_values<-rbind(values,values[2,,drop=FALSE])
  expect_error(aqt_ensemble_summarize(repeat_values,"value"),
               "More than one")
})
