#!/usr/bin/env Rscript
# Actual cross-OS elapsed-time and allocated-memory measurements.
# Synthetic trajectories; not a hardware-neutral service-level objective.
args<-commandArgs(trailingOnly=TRUE)
if(length(args)!=1L || file.exists(args[[1L]]) ||
   !dir.exists(dirname(args[[1L]])))
  stop("Supply a NEW benchmark output directory",call.=FALSE)
if(!requireNamespace("bench",quietly=TRUE))
  stop("Measured memory allocation requires bench; do not report unrun benchmarks",
       call.=FALSE)
suppressPackageStartupMessages(library(aquaTrajectories))
if(as.character(utils::packageVersion("aquaTrajectories"))!="0.1.2")
  stop("Release05 benchmark requires exact package version 0.1.2",
       call.=FALSE)
make_tracks<-function(n,three=FALSE){
  if(n %% 5L)stop("Benchmark sizes must be divisible by five")
  frame<-rep(seq_len(n/5L)-1L,each=5L)
  fish<-rep(seq_len(5L),n/5L)
  x<-frame*.09+fish*.55+sin(frame/8+fish)*.1
  y<-fish*1.5+cos(frame/11+fish)*.15
  d<-data.frame(session_id="bench",camera_id="tank",
    track_id=sprintf("%04d",fish),
    frame_id=frame,time_s=as.double(frame),
    x=x,y=y,observed=TRUE,stringsAsFactors=FALSE)
  if(three)d$z<-fish*.25+sin(frame/13+fish)*.2
  aqt_tracks(d,units="cm",coordinate_system="tank")
}
sha<-function(x)unname(digest::digest(x,algo="sha256"))
perform<-function(fun,name,t,n,three,repeats=3L) {
  # All output correctness checks run INSIDE the measured closure; any
  # benchmark iteration that returns an incorrect result hard-fails.
  gc(full=TRUE)
  mark<-bench::mark(measured=fun(),iterations=repeats,
                    min_time=0,check=FALSE,memory=TRUE)
  require<-function(x,nm)if(length(x)!=1L || !is.finite(x) || x<0)
     stop("No measured ",nm," produced for ",name,call.=FALSE)
  seconds<-as.numeric(mark$median[[1L]])
  minimum<-as.numeric(mark$min[[1L]])
  allocation<-as.numeric(mark$mem_alloc[[1L]])
  require(seconds,"median_seconds")
  require(minimum,"min_seconds")
  if(length(allocation)!=1L || !is.finite(allocation) || allocation<=0)
    stop("Missing measured allocated memory (bench::mark)",call.=FALSE)
  one<-fun()
  data.frame(workload=name,n_rows=n,n_fish=5L,
    dimension=if(three)3L else 2L,n_frames=as.integer(n/5L),
    iterations=repeats,median_seconds=seconds,min_seconds=minimum,
    allocated_bytes=allocation,
    source_object_bytes=as.numeric(object.size(t)),
    output_object_bytes=as.numeric(object.size(one)),
    source_object_sha256=sha(list(as.data.frame(t),
        units=attr(t,"aqt_units"),dimension=attr(t,"aqt_dimension"))),
    os=Sys.info()[["sysname"]],R_version=as.character(getRversion()),
    package_version="0.1.2",
    stringsAsFactors=FALSE)
}
results<-list();k<-0L
for(three in c(FALSE,TRUE)){
  for(n in c(1000L,5000L,20000L)) {
    tr<-make_tracks(n,three=three)
    coords<-c("x","y",if(three)"z")
    indexed<-split(seq_len(nrow(tr)),tr$track_id)
    # This is a separate numerical reference computed directly on original
    # coordinate differences; the package must agree every iteration.
    expected_lengths<-vapply(indexed,function(i){
      a<-as.matrix(tr[i,coords,drop=FALSE])
      delta<-a[-1L,,drop=FALSE]-a[-length(i),,drop=FALSE]
      sum(sqrt(rowSums(delta^2)))
    },numeric(1L))
    movement<-function(){
      r<-aqt_path_summary(tr,max_gap_s=1.01)
      z<-stats::setNames(r$path_length,r$track_id)
      if(!setequal(names(z),names(expected_lengths)) ||
         any(abs(z[names(expected_lengths)]-expected_lengths)>1e-8))
        stop("Path benchmark independent Euclidean reference failure",
             call.=FALSE)
      r
    }
    k<-k+1L
    results[[k]]<-perform(movement,"path_summary",tr,n,three)
    grouping<-function(){
      r<-aqt_group_metrics(tr,max_gap_s=1.01)
      if(nrow(r)!=n/5L || any(r$n_visible!=5L))
        stop("Five-fish group geometry has the wrong number of frames")
      if(abs(r$centroid_x[1L]-mean(tr$x[tr$time_s==0]))>1e-10 ||
         abs(r$centroid_y[nrow(r)]-
             mean(tr$y[tr$time_s==max(tr$time_s)]))>1e-10)
        stop("Group centroid differs from independent arithmetic mean")
      r
    }
    k<-k+1L
    results[[k]]<-perform(grouping,"group_geometry",tr,n,three)
    qc_work<-function(){
      r<-aqt_qc2_report(tr,gap_limits_s=1.01,speed_limits=Inf)
      if(nrow(r$lineage)!=n ||
         sum(r$lineage$step_eligible)!=n-5L ||
         any(r$lineage$step_status=="excluded_by_policy"))
        stop("Source-row QC benchmark excluded valid deterministic steps")
      r
    }
    k<-k+1L
    results[[k]]<-perform(qc_work,"qc2_lineage",tr,n,three)
    q<-qc_work()
    figure_work<-function(){
      r<-aqt_viz2_spec(q,figure="paths",policy_id="QC001",
                       preset="journal_single",
                       plane=if(three)"xz" else "xy")
      if(nrow(r$points)!=n || nrow(r$segments)!=n-5L)
        stop("Viz2 measured benchmark lost original source rows/steps")
      r
    }
    k<-k+1L
    results[[k]]<-perform(figure_work,
               if(three)"viz2_xz_spec" else "viz2_xy_spec",
               tr,n,three)
  }
}
table<-do.call(rbind,results)
rownames(table)<-NULL
if(nrow(table)!=24L || any(!is.finite(table$median_seconds)) ||
   any(table$allocated_bytes<=0))
  stop("Incomplete measured two-dimensional/three-dimensional benchmark")
dir.create(args[[1L]])
out<-args[[1L]]
file<-file.path(out,"RELEASE05_BENCHMARK.csv")
utils::write.csv(table,file,row.names=FALSE,na="")
writeLines(c("# AquaTrajectories v0.1.2 performance baseline",
 "Actual bench::mark measurements, 3 iterations per workload.",
 "24 workloads: 2 dimensions x 3 source sizes x 4 actual scientific APIs.",
 "median_seconds and min_seconds are elapsed times reported by bench.",
 "allocated_bytes is actual R tracked allocation from bench::mark,",
 "NOT peak process RSS, GPU memory, or total system RAM.",
 "source_object_bytes and output_object_bytes use base::object.size;",
 "they are NOT resident-set high-water marks.",
 "All workloads use explicit source clocks, manual expected geometry,",
 "original row IDs and no video-decoder or network operations.",
 "Performance thresholds are NOT cross-hardware service-level assertions;",
 "different CPUs, OS, CRAN binary versions, and scheduling affect time.",
 "The CI gate checks numerical truth, measured finite nonzero allocation",
 "and complete provenance; it does not assert performance superiority.",
 "",capture.output(utils::sessionInfo())),
 file.path(out,"PERFORMANCE_README.txt"),useBytes=TRUE)
sha_file<-function(p)unname(digest::digest(p,file=TRUE,algo="sha256"))
manifest<-list(schema="AQT_RELEASE05_PERFORMANCE_BASELINE_V1",
  status="MEASURED_24_WORKLOADS",
  tested_rows=c(1000L,5000L,20000L),
  scientific_dimensions=c(2L,3L),
  iterations=3L,n_runs=nrow(table),
  os=Sys.info()[["sysname"]],
  package_version="0.1.2",
  run_not_cross_hardware_SLA=TRUE,
  measured_allocation_not_peak_rss=TRUE,
  benchmark_source_sha256=sha_file("scripts/release05_benchmark.R"),
  benchmark_csv_sha256=sha_file(file),
  readme_sha256=sha_file(file.path(out,"PERFORMANCE_README.txt")))
jsonlite::write_json(manifest,file.path(out,"BENCHMARK_MANIFEST.json"),
                     auto_unbox=TRUE,pretty=TRUE)
cat("RELEASE05_MEASURED_BENCHMARK_PASS:",nrow(table),
    "runtime + tracked-memory workloads on",
    Sys.info()[["sysname"]],"\n")
