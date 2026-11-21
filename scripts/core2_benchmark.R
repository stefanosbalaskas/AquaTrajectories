#!/usr/bin/env Rscript
# Deterministic trajectory workload benchmark. No camera/video dependencies.
# Usage: Rscript scripts/core2_benchmark.R NEW_OUTPUT_DIR [comma-separated sample sizes]
args <- commandArgs(trailingOnly=TRUE)
if(length(args)<1L || length(args)>2L)stop("Supply new output directory and optional sizes")
output <- args[[1L]]
if(file.exists(output) || !dir.exists(dirname(output)))
  stop("Output path must be new with existing parent")
sizes <- if(length(args)==2L) suppressWarnings(as.integer(strsplit(args[[2L]],",",fixed=TRUE)[[1L]])) else c(1000L,10000L)
if(!length(sizes) || anyNA(sizes) || any(sizes<100L) || any(sizes>1000000L) || anyDuplicated(sizes))
  stop("sizes must be unique integers from 100 to 1,000,000")
suppressPackageStartupMessages(library(aquaTrajectories))
results <- list();j<-0L
for(n in sizes) {
  d <- data.frame(session_id="benchmark",camera_id="external",track_id="A",
    time_s=(seq_len(n)-1)*.1,x=(seq_len(n)-1)*.5,y=rep(0,n),
    observed=TRUE,stringsAsFactors=FALSE)
  t <- aqt_tracks(d,units="cm",coordinate_system="tank")
  source_hash <- digest::digest(d,algo="sha256")
  for(rep in seq_len(3L)) {
    gc()
    before <- proc.time()[["elapsed"]]
    p <- aqt_path_summary(t,max_gap_s=.10001)
    elapsed <- proc.time()[["elapsed"]]-before
    if(nrow(p)!=1L || p$valid_steps!=(n-1L) ||
       abs(p$path_length-.5*(n-1L))>1e-7 ||
       abs(p$mean_speed-5)>1e-7)
      stop("Known-answer numerical benchmark failed for ",n)
    j<-j+1L
    results[[j]] <- data.frame(n_observations=n,repeat_id=rep,
      elapsed_seconds=elapsed,source_object_bytes=as.numeric(object.size(t)),
      path_length=p$path_length,valid_steps=p$valid_steps,
      mean_speed=p$mean_speed,source_digest=source_hash)
  }
}
dir.create(output)
bench <- do.call(rbind,results)
utils::write.csv(bench,file.path(output,"CORE2_BENCHMARK.csv"),row.names=FALSE)
writeLines(c("# Scientific Core 2.0 deterministic performance evidence",
    "", "These are measured elapsed times on synthetic trajectories, not cross-machine SLAs.",
    "Object size is R object.size, not peak RSS or total allocated memory.",
    "Only numerical correctness is an automated gate; speed comparisons need identical environment.",
    "",capture.output(utils::sessionInfo())),file.path(output,"README.txt"))
sha <- list(schema="AQT_CORE2_PERFORMANCE_V1",
            raw_fish_data_used=FALSE,release_performance_certified=FALSE,
            files=list(CORE2_BENCHMARK.csv=unname(digest::digest(
             file.path(output,"CORE2_BENCHMARK.csv"),file=TRUE,algo="sha256")),
             README.txt=unname(digest::digest(file.path(output,"README.txt"),
              file=TRUE,algo="sha256"))))
jsonlite::write_json(sha,file.path(output,"PERFORMANCE_MANIFEST.json"),
                     pretty=TRUE,auto_unbox=TRUE)
cat("CORE2_BENCHMARK_KNOWN_ANSWER_PASS sizes",paste(sizes,collapse=","),"\n")
