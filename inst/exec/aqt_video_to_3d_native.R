#!/usr/bin/env Rscript
# Immutable source PyAV/YOLO/ByteTrack bundle -> native automatic refractive 3D.
# The input engine JSON is produced by aqt_video_to_3d.py; never evals R strings.
args <- commandArgs(trailingOnly=TRUE)
if (length(args)!=2L) stop("Need engine JSON and existing output directory")
input <- args[[1L]];out <- args[[2L]]
if (!file.exists(input) || !dir.exists(out))
  stop("Missing externally declared source engine or output directory")
if (!requireNamespace("jsonlite",quietly=TRUE))
  stop("Install jsonlite for native 3D runner")
if (requireNamespace("aquaTrajectories",quietly=TRUE)) {
  library(aquaTrajectories)
} else if (requireNamespace("pkgload",quietly=TRUE)) {
  pkgload::load_all(".",quiet=TRUE)
} else stop("Install aquaTrajectories or development pkgload")
cfg <- jsonlite::fromJSON(input,simplifyVector=FALSE)
if (!identical(cfg$schema_version,"1.0") ||
    !is.list(cfg$cameras) || length(cfg$cameras)<2L ||
    !is.character(cfg$session_id) ||
    !is.character(cfg$input_config_sha256))
  stop("Malformed native 3D source interface configuration")
numeric_scalar <- function(x,label,minimum=-Inf) {
  n <- unlist(x,use.names=FALSE)
  if (!is.numeric(n) || length(n)!=1L || !is.finite(n) || n<minimum)
    stop("Invalid original numerical ",label)
  n
}
original_matrix <- function(x,label) {
  if (!is.list(x) || length(x)!=3L ||
      any(vapply(x,length,integer(1L))!=3L))
    stop("Invalid 3x3 original camera ",label)
  a <- matrix(as.numeric(unlist(x,use.names=FALSE)),3L,3L,byrow=TRUE)
  if (any(!is.finite(a))) stop("Nonfinite 3x3 camera ",label)
  a
}
original_vector <- function(x,label) {
  a <- as.numeric(unlist(x,use.names=FALSE))
  if (length(a)!=3L || any(!is.finite(a)))
    stop("Invalid 3-vector original camera ",label)
  a
}
camera_model <- function(source) {
  c <- source$calibration
  K <- original_matrix(c$K,"K")
  rotation <- original_matrix(c$R_c2w,"R_c2w")
  center <- original_vector(c$center,"center")
  origin <- original_vector(c$plane_point,"plane_point")
  normal <- original_vector(c$plane_normal,"plane_normal")
  n_before <- numeric_scalar(c$n_before,"n_before",.000001)
  n_after <- numeric_scalar(c$n_after,"n_after",.000001)
  if (identical(c$model,"parallel_flatport")) {
    return(aqt_flatport_camera(K,rotation,center,origin,normal,
      glass_thickness=numeric_scalar(c$glass_thickness,
        "glass_thickness",.000001),
      n_first=n_before,n_glass=n_after,
      n_water=numeric_scalar(c$n_water,"n_water",.000001),
      units=c$units))
  }
  if (identical(c$model,"single_interface"))
    return(aqt_refractive_camera(K,rotation,center,origin,normal,
      n_before=n_before,n_after=n_after,units=c$units))
  stop("Unknown optical model: cannot invent underwater refraction")
}
frames_list <- list();tracks_list <- list();models <- list()
source_metadata <- list()
for (j in seq_along(cfg$cameras)) {
  c <- cfg$cameras[[j]]
  bundle <- aqt_video_bundle_import(c$bundle_dir,c$prefix)
  if (!identical(bundle$metadata$session_id,cfg$session_id) ||
      !identical(bundle$metadata$camera_id,c$camera_id) ||
      !identical(bundle$output_sha256_verified,TRUE))
    stop("Original source camera scope or SHA-256 bundle mismatch")
  clock <- c$clock
  if (!is.character(clock$source) ||
      !clock$source %in% c("unverified_relative_pts",
                          "externally_measured_affine"))
    stop("External clock origin unknown, cannot align source camera time")
  offset <- numeric_scalar(clock$offset_s,"camera offset")
  slope <- numeric_scalar(clock$scale,"camera slope",.00000001)
  camera_id <- c$camera_id
  if (camera_id %in% names(models))
    stop("Repeated scoped camera in source video configuration")
  models[[camera_id]] <- camera_model(c)
  raw_frame <- as.data.frame(bundle$frames)
  raw_frame$raw_time_s <- raw_frame$time_s
  raw_frame$time_s <- offset+slope*raw_frame$time_s
  frames_list[[j]] <- raw_frame
  raw_tracks <- as.data.frame(bundle$tracks)
  if (nrow(raw_tracks)) {
    raw_tracks$raw_time_s <- raw_tracks$time_s
    raw_tracks$time_s <- offset+slope*raw_tracks$time_s
  }
  tracks_list[[camera_id]] <- aqt_tracks(raw_tracks,
    units="px",coordinate_system="image")
  source_metadata[[j]] <- list(
    source_camera=camera_id,original_video_sha256=bundle$metadata$video_sha256,
    detector_weights_sha256=bundle$metadata$weights_sha256,
    source_frames=nrow(raw_frame),source_track_boxes=nrow(raw_tracks),
    source_bundle_sha256_verified=TRUE,
    clock_source=clock$source,clock_offset_s=offset,clock_scale=slope,
    detector_model_accuracy_independently_certified=FALSE,
    hardware_camera_exposure_sync_certified=FALSE)
}
if (length(unique(vapply(models,function(x)x$units,character(1L))))!=1L)
  stop("Stereo physical units must agree")
max_skew <- numeric_scalar(cfg$max_skew_s,"max_skew_s",0)
max_ray <- numeric_scalar(cfg$max_ray_separation,"max_ray_separation",0)
support <- numeric_scalar(cfg$min_support,"min_support",1)
margin <- numeric_scalar(cfg$ambiguity_margin,"ambiguity_margin",0)
primary <- names(models)[1L]
pairs <- list();xyz_list <- list();links_list <- list()
for (camera_b in names(models)[-1L]) {
  if (!nrow(tracks_list[[primary]]) || !nrow(tracks_list[[camera_b]])) {
    pairs[[length(pairs)+1L]] <- list(camera_a=primary,camera_b=camera_b,
      n_candidates=0L,n_auto_source_links=0L,n_3d_rows=0L,
      status="no_source_fish_detections",external_identity_certified=FALSE)
    next
  }
  result <- aqt_auto_refractive_pipeline(tracks_list[[primary]],
    tracks_list[[camera_b]],models[[primary]],models[[camera_b]],
    max_skew_s=max_skew,max_ray_separation=max_ray,
    min_support=support,ambiguity_margin=margin)
  pairs[[length(pairs)+1L]] <- list(
    camera_a=primary,camera_b=camera_b,
    n_candidates=nrow(result$candidates),
    n_auto_source_links=nrow(result$association$links),
    n_ambiguous_abstentions=result$association$n_ambiguous_abstentions,
    n_3d_rows=if(is.null(result$tracks_3d))0L else nrow(result$tracks_3d),
    status=result$status,external_identity_certified=FALSE)
  if (!is.null(result$tracks_3d)) {
    xyz <- as.data.frame(result$tracks_3d)
    # With >2 views each reference-to-other pair has a separate 3D track
    # identity. Do NOT claim a physically global N-camera biological ID.
    xyz$track_id <- paste(camera_b,xyz$track_id,sep="_")
    xyz$source_camera_b <- camera_b
    xyz_list[[length(xyz_list)+1L]] <- xyz
    links <- result$association$links
    links$camera_a <- primary;links$camera_b <- camera_b
    links$fish_id <- paste(camera_b,links$fish_id,sep="_")
    links_list[[length(links_list)+1L]] <- links
  }
}
all_frames <- do.call(rbind,frames_list)
utils::write.csv(all_frames,file.path(out,"source_frames.csv"),
                 row.names=FALSE,na="")
all_tracks <- do.call(rbind,lapply(tracks_list,as.data.frame))
utils::write.csv(all_tracks,file.path(out,"source_2d_tracks.csv"),
                 row.names=FALSE,na="")
if (length(xyz_list)) {
  xyz <- do.call(rbind,xyz_list)
} else {
  xyz <- data.frame(session_id=character(),camera_id=character(),
    track_id=character(),time_s=numeric(),x=numeric(),y=numeric(),
    z=numeric(),observed=logical(),source_camera_a=character(),
    source_camera_b=character(),source_id_a=character(),
    source_id_b=character(),ray_separation=numeric(),
    time_skew_s=numeric(),stringsAsFactors=FALSE)
}
utils::write.csv(xyz,file.path(out,"fish_3d_tracks.csv"),
                 row.names=FALSE,na="")
if (length(links_list)) {
  links <- do.call(rbind,links_list)
} else {
  links <- data.frame(session_id=character(),id_a=character(),
    id_b=character(),fish_id=character(),
    n_supported_observations=integer(),
    median_geometry_error=numeric(),median_time_skew_s=numeric(),
    camera_a=character(),camera_b=character(),stringsAsFactors=FALSE)
}
utils::write.csv(links,file.path(out,"crossview_links.csv"),
                 row.names=FALSE,na="")
report <- list(
  schema_version="1.0",status=if(nrow(xyz))
    "auto_video_to_3d_provisional_geometry" else
    "no_unambiguous_crossview_3d_observations",
  input_config_sha256=cfg$input_config_sha256,
  session_id=cfg$session_id,
  source_execution_mode=cfg$source_execution_mode,
  original_camera_records=source_metadata,
  source_frame_count=nrow(all_frames),
  source_2d_track_rows=nrow(all_tracks),
  pairwise_camera_results=pairs,
  n_provisional_pair_ids=nrow(links),
  n_3d_rows=nrow(xyz),
  source_3d_units=models[[primary]]$units,
  multi_view_global_reidentification_certified=FALSE,
  hardware_camera_exposure_sync_certified=FALSE,
  biological_identity_certified=FALSE,
  underwater_physical_xyz_accuracy_certified=FALSE,
  detector_and_tracker_original_video_truth_blind_certified=FALSE,
  uncertainty_interval_calibrated=FALSE,
  actual_animal_welfare_tested=FALSE,
  original_source_video_time_claim="decoded_local_PTS; external clock mapping declared but independently unverified")
jsonlite::write_json(report,file.path(out,"stereo_audit.json"),
  auto_unbox=TRUE,pretty=TRUE,digits=NA)
cat(jsonlite::toJSON(report,auto_unbox=TRUE,pretty=TRUE),"\n")
