#!/usr/bin/env Rscript
# Scientific Core group-level benchmark: actual measured times; no SLA.
# Usage: Rscript scripts/qc2_group_benchmark.R NEW_OUTPUT_FOLDER
args <- commandArgs(trailingOnly=TRUE)
if(length(args)!=1L || file.exists(args[[1L]]) ||
   !dir.exists(dirname(args[[1L]])))
  stop("Supply new output directory under an existing parent")
suppressPackageStartupMessages(library(aquaTrajectories))
out <- list();j <- 0L
for(nfish in c(5L,20L,50L,100L)) for(dimn in c(2L,3L)) {
  nframes <- 60L
  d <- expand.grid(track_id=sprintf("fish%03d",seq_len(nfish)),
                   time_s=(seq_len(nframes)-1)*.1,
                   KEEP.OUT.ATTRS=FALSE,stringsAsFactors=FALSE)
  k <- as.integer(sub("fish","",d$track_id))
  d$session_id <- "bench"
  d$camera_id <- "tank"
  d$x <- as.double(k)
  d$y <- as.double(d$time_s)
  if(dimn==3L)d$z <- rep(3,nrow(d))
  d$observed <- TRUE
  t <- aqt_tracks(d,units="cm",coordinate_system="tank")
  for(rep in seq_len(3L)) {
    gc()
    start <- proc.time()[["elapsed"]]
    g <- aqt_group_metrics(t,max_gap_s=.101)
    elapsed <- proc.time()[["elapsed"]]-start
    if(nrow(g)!=nframes || any(g$n_visible!=nfish) ||
       any(abs(g$centroid_x-(nfish+1)/2)>1e-9) ||
       any(abs(g$mean_nearest_neighbor-1)>1e-9) ||
       any(abs(g$centroid_y-(g$time_s))>1e-9))
      stop("Independent group geometry known-answer check failed")
    if(any(abs(g$polarization[-1L]-1)>1e-9,na.rm=TRUE))
      stop("Collinear unit-velocity polarization failed")
    j<-j+1L
    out[[j]] <- data.frame(dimension=dimn,n_fish=nfish,
      n_frames=nframes,n_positions=nrow(t),repeat_id=rep,
      elapsed_seconds=elapsed,track_object_bytes=as.numeric(object.size(t)),
      output_object_bytes=as.numeric(object.size(g)),
      mean_nearest_neighbor=mean(g$mean_nearest_neighbor),
      n_valid_frames=nrow(g),stringsAsFactors=FALSE)
  }
}
dir.create(args[[1L]])
data <- do.call(rbind,out)
utils::write.csv(data,file.path(args[[1L]],"GROUP_SCALING.csv"),
                 row.names=FALSE)
writeLines(c("Measured synthetic multi-individual/group geometry benchmark",
 "No linear-scaling claim: nearest-neighbor distances are quadratic in fish count.",
 "Recorded object.size is not peak RSS or total allocated memory.",
 "All known-answer checks are required; timings are descriptive and hardware-specific.",
 "",capture.output(utils::sessionInfo())),
 file.path(args[[1L]],"README.txt"),useBytes=TRUE)
hash <- unname(digest::digest(file.path(args[[1L]],"GROUP_SCALING.csv"),
                               file=TRUE,algo="sha256"))
jsonlite::write_json(list(schema="AQT_GROUP_SCALING_V1",
  synthetic_only=TRUE,n_observations=nrow(data),csv_sha256=hash,
  validated_real_biology=FALSE),
  file.path(args[[1L]],"GROUP_SCALING_MANIFEST.json"),
  auto_unbox=TRUE,pretty=TRUE)
cat("GROUP_SCALING_KNOWN_ANSWER_PASS: ",nrow(data),"runs\n")
