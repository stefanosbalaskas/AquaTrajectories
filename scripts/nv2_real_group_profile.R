#!/usr/bin/env Rscript
# Exact-source, real-annotation group scaling. No source track predictions
# or physical seconds are fabricated; ordinal frame IDs serve ONLY as an
# equality key for per-frame geometry, not speed or time inference.
args<-commandArgs(trailingOnly=TRUE)
if(length(args)!=3L)stop("Usage: Rscript nv2_real_group_profile.R CSV PROVENANCE_JSON NEW_OUTPUT_DIR")
csv<-args[[1L]];manifest<-args[[2L]];out<-args[[3L]]
if(!file.exists(csv)||!file.exists(manifest)||
   file.exists(out)||!dir.exists(dirname(out)))
  stop("Source files must exist and destination must be new")
suppressPackageStartupMessages(library(aquaTrajectories))
sha<-function(path)unname(digest::digest(path,file=TRUE,algo="sha256"))
meta<-jsonlite::fromJSON(manifest,simplifyVector=FALSE)
if(!identical(meta$schema,"NV2_REAL_MOT_ANNOTATION_SOURCE_V1")||
   !identical(meta$csv_sha256,sha(csv)) ||
   !identical(meta$clock_status,"ORDINAL_FRAME_PROXY_NOT_SECONDS")||
   !identical(meta$coordinate_units,"px")||
   !identical(meta$data_origin,
     "original_downloaded_annotation_gt_NOT_tracker_predictions"))
  stop("Real annotation source hash, units or provenance contract invalid")
tr<-aqt_import_csv(csv,units="px",coordinate_system="image")
if(!"frame_id" %in% names(tr) ||
   any(tr$time_s!=tr$frame_id-min(tr$frame_id)))
  stop("Frame proxy does not match original ordinal frame positions")
if(nrow(tr)!=meta$n_source_observations ||
   length(unique(tr$track_id))!=meta$n_tracks ||
   length(unique(tr$frame_id))!=meta$n_frames)
  stop("Source row, scope or frame counts changed after conversion")
track_ids<-sort(unique(as.character(tr$track_id)))
if(length(track_ids)<2L)stop("At least two real annotated IDs required")
sizes<-unique(c(10L,25L,50L,100L,200L,length(track_ids)))
sizes<-sizes[sizes<=length(track_ids) & sizes>=2L]
rows<-list();num<-0L
for(nfish in sizes) {
  selected<-tr[tr$track_id %in% track_ids[seq_len(nfish)],,drop=FALSE]
  selected<-aqt_tracks(as.data.frame(selected),units="px",
                       coordinate_system="image")
  # Compare real sampled frame geometry to independent base-R
  # distance matrix, not to any package group helper.
  frame_keys<-sort(unique(selected$frame_id))
  target_frame<-frame_keys[which.max(vapply(frame_keys,function(f)
    sum(selected$frame_id==f),integer(1L)))]
  for(repeat_id in 1:2) {
    gc()
    before<-proc.time()[["elapsed"]]
    g<-aqt_group_metrics(selected,max_gap_s=Inf)
    seconds<-proc.time()[["elapsed"]]-before
    if(!nrow(g))stop("No real input groups")
    gg<-g[g$time_s==target_frame-min(tr$frame_id),,drop=FALSE]
    xx<-selected[selected$frame_id==target_frame,,drop=FALSE]
    xyz<-as.matrix(xx[,c("x","y"),drop=FALSE])
    if(nrow(gg)!=1L||gg$n_visible!=nrow(xx)||
       any(abs(c(gg$centroid_x,gg$centroid_y)-colMeans(xyz))>1e-8))
      stop("Real-source independent group centroid/visibility oracle failed")
    if(nrow(xyz)>=2L) {
      pair<-as.matrix(stats::dist(xyz))
      diag(pair)<-Inf
      reference<-mean(apply(pair,1L,min))
      if(abs(gg$mean_nearest_neighbor-reference)>1e-8)
        stop("Real-source nearest-neighbor oracle mismatch")
    }
    num<-num+1L
    rows[[num]]<-data.frame(
      source_sequence=meta$sequence,n_unique_ids_available=length(track_ids),
      nominal_id_subset=nfish,n_real_input_rows=nrow(selected),
      n_recorded_frames=length(frame_keys),
      max_simultaneous_visible=max(g$n_visible),
      observed_frame_index_reference=target_frame,
      output_group_rows=nrow(g),
      elapsed_seconds=seconds,
      input_object_bytes=as.double(object.size(selected)),
      output_object_bytes=as.double(object.size(g)),
      coordinate_units="px",time_status="frame_index_proxy_NOT_seconds",
      repeat_id=repeat_id,synthetic_data_used=FALSE,
      stringsAsFactors=FALSE)
  }
}
dir.create(out)
values<-do.call(rbind,rows)
utils::write.csv(values,file.path(out,"REAL_GROUP_PERFORMANCE.csv"),
                 row.names=FALSE,na="")
report<-list(schema="NV2_REAL_ANNOTATION_GROUP_PERFORMANCE_V1",
   source_provenance=meta,
   n_analytical_repetitions=nrow(values),
   n_original_rows=nrow(tr),
   n_observed_source_tracks=length(track_ids),
   n_observed_source_frames=length(unique(tr$frame_id)),
   original_source_sha256=meta$source_zip_sha256,
   source_csv_sha256=sha(csv),
   performance_csv_sha256=sha(file.path(out,"REAL_GROUP_PERFORMANCE.csv")),
   independent_group_geometry_checked=TRUE,
   original_zip_transport_TLS_verified=FALSE,
   source_content_independently_authenticated=FALSE,
   physical_time_used=FALSE,
   inferential_fish_movement_certified=FALSE,
   full_process_peak_RSS_measured=FALSE)
jsonlite::write_json(report,file.path(out,"REAL_GROUP_MANIFEST.json"),
                     pretty=TRUE,auto_unbox=TRUE,null="null")
cat("NV2_REAL_GROUP_PROFILE_PASS",
    meta$sequence,"input_rows",nrow(tr),"ID",length(track_ids),
    "bench_runs",nrow(values),"\n")
