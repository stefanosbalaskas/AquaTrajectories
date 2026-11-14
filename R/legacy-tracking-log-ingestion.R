# Wave 17: legacy tracking comma-split tracking exports.
# Private real fish logs are NOT bundled in the public package.
# Source clock is per-ID relative, not a shared camera/video timestamp.
# "Depth(cm)" remains an unverified distance-like measurement; it is
# neither tank z nor physical water-column depth without a camera model.

#' Import a legacy tracking stereo tracking-log export without losing observations
#'
#' The header reports eight names but numeric observation rows contain eleven
#' comma-delimited fields: the final three header fields are XY coordinate
#' pairs. This importer reads all eleven, SHA-256 fingerprints the original,
#' and retains each source line. No fitted calibration, global timestamp,
#' synchronized identity, video PTS, or physical speed is inferred.
#'
#' @param path Path to one original *_tracking_log.txt file.
#' @param session_id Optional unique identifier; defaults to filename stem.
#' @param camera_id Exported-camera label. Defaults to "unverified"; no
#'   particular camera is inferred from L_11025/L_29925 filenames.
#' @param image_size Integer image width/height pixels (default 1920x1080
#'   based on supplied exports, not verified sensor geometry).
#' @param depth_threshold_cm Descriptive source-analysis depth cutoff for
#'   a flag, NOT a calibrated limit on actual water-column depth.
#' @return aqt_tracking_log_export with raw values, QC flags, hash/provenance.
#' @export
aqt_import_tracking_log <- function(
    path,session_id=NULL,camera_id="unverified",
    image_size=c(1920,1080),depth_threshold_cm=200) {
  if (!is.character(path) || length(path)!=1L || is.na(path) ||
      !file.exists(path) || dir.exists(path))
    stop("path must be an existing source tracking-log file",call.=FALSE)
  if (!is.numeric(image_size) || length(image_size)!=2L ||
      any(!is.finite(image_size)) || any(image_size<=0) ||
      any(image_size!=floor(image_size)))
    stop("image_size must contain positive integer width and height",
         call.=FALSE)
  if (!is.numeric(depth_threshold_cm) || length(depth_threshold_cm)!=1L ||
      !is.finite(depth_threshold_cm) || depth_threshold_cm<=0)
    stop("depth_threshold_cm must be positive and finite",call.=FALSE)
  if (is.null(session_id))
    session_id <- tools::file_path_sans_ext(basename(path))
  for (id in list(session_id,camera_id))
    if (!is.character(id) || length(id)!=1L || is.na(id) ||
        !nzchar(trimws(id)))
      stop("session_id and camera_id must be nonblank strings",call.=FALSE)
  nfields <- utils::count.fields(
    path,sep=",",quote="",blank.lines.skip=FALSE)
  if (length(nfields)<2L || !identical(as.integer(nfields[1L]),8L) ||
      anyNA(nfields[-1L]) || any(nfields[-1L]!=11L))
    stop("Expected original legacy tracking 8-field header and exactly 11",
         " numeric fields on every observation line",call.=FALSE)
  header <- strsplit(readLines(path,n=1L,warn=FALSE),",",
                     fixed=TRUE)[[1L]]
  header <- trimws(header)
  if (!identical(header,c("Fish_ID","Width(px)","Height(px)",
                          "Depth(cm)","Time","Top_Left","Bottom_Right",
                          "Center_Point")) &&
      !identical(header,c("Fish_ID","Width","Height",
                          "Depth(cm)","Time","Top_Left","Bottom_Right",
                          "Center_Point")))
    stop("Unrecognized legacy tracking tracking-log header",call.=FALSE)
  cols <- c("fish_id","width_px","height_px","depth_raw_cm",
            "track_time_s","tl_x","tl_y","br_x","br_y",
            "center_x","center_y")
  d <- utils::read.csv(path,header=FALSE,skip=1L,col.names=cols,
                       colClasses=rep("numeric",11L),
                       stringsAsFactors=FALSE,check.names=FALSE)
  if (nrow(d)!=length(nfields)-1L ||
      any(!vapply(d,function(z) is.numeric(z) &&
                   all(is.finite(z)),logical(1L))))
    stop("Source line count or numeric fields are invalid",call.=FALSE)
  if (any(d$fish_id<0 | d$fish_id!=floor(d$fish_id)) ||
      any(d$fish_id>2^53-1))
    stop("fish_id must be an exact nonnegative integer",call.=FALSE)
  if (any(d$track_time_s<0))
    stop("track-relative time cannot be negative",call.=FALSE)
  d$fish_id <- format(d$fish_id,scientific=FALSE,trim=TRUE)
  d$source_line <- seq_len(nrow(d))+1L
  d$source_file <- basename(path)
  d$session_id <- session_id
  d$camera_id <- camera_id
  nm <- basename(path)
  phase <- if(grepl("^BEFORE_",nm,ignore.case=TRUE)) "Before" else
    if(grepl("^DURING_",nm,ignore.case=TRUE)) "During" else
    if(grepl("^AFTER_",nm,ignore.case=TRUE)) "After" else "Unclassified"
  d$filename_phase <- phase
  key <- paste(d$fish_id,format(d$track_time_s,digits=17),sep="\r")
  d$qc_duplicate_id_time <- duplicated(key) |
                              duplicated(key,fromLast=TRUE)
  d$qc_nonincreasing_track_clock <- rep(FALSE,nrow(d))
  track_rows <- split(seq_len(nrow(d)),d$fish_id)
  for (ii in track_rows) if(length(ii)>1L) {
    dt <- diff(d$track_time_s[ii])
    d$qc_nonincreasing_track_clock[ii[-1L]] <- dt<=0
  }
  d$qc_invalid_box_geometry <- d$width_px<=0 | d$height_px<=0 |
    d$br_x<d$tl_x | d$br_y<d$tl_y |
    abs(d$br_x-d$tl_x-d$width_px)>1 |
    abs(d$br_y-d$tl_y-d$height_px)>1 |
    abs(d$center_x-(d$br_x+d$tl_x)/2)>1 |
    abs(d$center_y-(d$br_y+d$tl_y)/2)>1
  d$qc_box_outside_image <- d$tl_x<0 | d$tl_y<0 |
                            d$br_x>image_size[1L] |
                            d$br_y>image_size[2L]
  d$qc_box_on_boundary <- d$tl_x<=1 | d$tl_y<=1 |
    d$br_x>=image_size[1L]-1L | d$br_y>=image_size[2L]-1L
  d$qc_depth_at_or_above_cutoff <- d$depth_raw_cm>=depth_threshold_cm
  d$qc_depth_nonpositive <- d$depth_raw_cm<=0
  class(d) <- c("aqt_tracking_log_export","data.frame")
  attr(d,"aqt_source_sha256") <- digest::digest(
    path,algo="sha256",file=TRUE)
  attr(d,"aqt_clock_scope") <- "per_track_relative_not_global_PTS"
  attr(d,"aqt_depth_interpretation") <-
    "unknown_camera_distance_or_depth_not_tank_Z"
  attr(d,"aqt_image_size_assumed_px") <- image_size
  attr(d,"aqt_depth_cutoff_source_convention_cm") <- depth_threshold_cm
  attr(d,"aqt_animal_identity_certified") <- FALSE
  attr(d,"aqt_underwater_3d_certified") <- FALSE
  attr(d,"aqt_tank_replication_certified") <- FALSE
  d
}

#' Audit original legacy tracking observations without deleting flagged rows
#'
#' @param logs One aqt_tracking_log_export or a nonempty list of them.
#' @return Per-source-file counts, track fragmentation, clock resets,
#'   boundaries, duplicate source times and estimated-depth flags.
#' @export
aqt_tracking_log_audit <- function(logs) {
  if (inherits(logs,"aqt_tracking_log_export")) logs <- list(logs)
  if (!is.list(logs) || !length(logs) ||
      !all(vapply(logs,inherits,logical(1L),"aqt_tracking_log_export")))
    stop("logs must contain one or more aqt_tracking_log_export objects",
         call.=FALSE)
  out <- lapply(logs,function(x) {
    ids <- unique(x$fish_id)
    lengths <- as.numeric(table(x$fish_id))
    first <- !duplicated(x$fish_id)
    data.frame(source_file=unique(x$source_file)[1L],
      session_id=unique(x$session_id)[1L],
      filename_phase=unique(x$filename_phase)[1L],
      n_observations=nrow(x),n_track_ids=length(ids),
      median_rows_per_track=stats::median(lengths),
      n_track_clocks_start_at_zero=sum(x$track_time_s[first]==0),
      n_duplicate_id_time_rows=sum(x$qc_duplicate_id_time),
      n_nonincreasing_clock_rows=sum(x$qc_nonincreasing_track_clock),
      n_boundary_rows=sum(x$qc_box_on_boundary),
      n_outside_image_rows=sum(x$qc_box_outside_image),
      n_bad_box_geometry_rows=sum(x$qc_invalid_box_geometry),
      n_depth_at_or_above_cutoff=sum(x$qc_depth_at_or_above_cutoff),
      n_nonpositive_depth=sum(x$qc_depth_nonpositive),
      max_raw_depth_cm=max(x$depth_raw_cm),
      max_track_relative_time_s=max(x$track_time_s),
      sha256_source=attr(x,"aqt_source_sha256"),
      stringsAsFactors=FALSE)
  })
  result <- do.call(rbind,out)
  rownames(result) <- NULL
  attr(result,"not_global_camera_timestamps") <- TRUE
  attr(result,"fish_identity_accuracy_certified") <- FALSE
  attr(result,"estimated_depth_is_validated_water_depth") <- FALSE
  result
}

#' Create provisional image-plane tracks from legacy tracking source observations
#'
#' Duplicate track-local timestamps violate aqt_tracks uniqueness. The
#' default drops *all* rows participating in any duplicate rather than
#' arbitrarily preferring one conflicting depth or fish position. The other
#' QC flags remain visible on retained tracks unless explicitly excluded.
#' No source depth is interpreted as XYZ z, nor is a global clock inferred.
#'
#' @param x One aqt_tracking_log_export.
#' @param duplicate_policy drop_all, first, or error.
#' @param drop_bad_boxes Remove impossible/out-of-image boxes.
#' @param drop_boundary Remove boxes touching an image border.
#' @param drop_depth_cutoff Remove rows at/above the **source-analysis**
#'   depth cutoff (does not certify z-depth).
#' @return aqt_tracks in pixels, with 2D image centres and raw-depth
#'   auxiliary column plus unverified provenance attributes.
#' @export
aqt_tracking_log_tracks <- function(
    x,duplicate_policy=c("drop_all","first","error"),
    drop_bad_boxes=TRUE,drop_boundary=FALSE,
    drop_depth_cutoff=FALSE) {
  if (!inherits(x,"aqt_tracking_log_export"))
    stop("Expected aqt_tracking_log_export",call.=FALSE)
  duplicate_policy <- match.arg(duplicate_policy)
  for (v in list(drop_bad_boxes,drop_boundary,drop_depth_cutoff))
    if(!is.logical(v) || length(v)!=1L || is.na(v))
      stop("Filtering controls must be TRUE or FALSE",call.=FALSE)
  if (duplicate_policy=="error" && any(x$qc_duplicate_id_time))
    stop("Duplicate source ID-time observations; no policy selected",
         call.=FALSE)
  keep <- rep(TRUE,nrow(x))
  if (duplicate_policy=="drop_all")
    keep <- keep & !x$qc_duplicate_id_time
  if (duplicate_policy=="first") {
    key <- paste(x$fish_id,format(x$track_time_s,digits=17),sep="\r")
    keep <- keep & !duplicated(key)
  }
  if (drop_bad_boxes)
    keep <- keep & !x$qc_invalid_box_geometry &
      !x$qc_box_outside_image
  if (drop_boundary) keep <- keep & !x$qc_box_on_boundary
  if (drop_depth_cutoff)
    keep <- keep & !x$qc_depth_at_or_above_cutoff
  if (!any(keep))
    stop("No tracking observations remain after QC filters",call.=FALSE)
  d <- x[keep,,drop=FALSE]
  # Do not accidentally inherit the legacy tracking raw-data S3 class.
  d <- as.data.frame(d)
  d$track_id <- d$fish_id
  d$time_s <- d$track_time_s
  d$x <- d$center_x
  d$y <- d$center_y
  d$z <- NA_real_
  d$observed <- TRUE
  tracks <- aqt_tracks(d,units="px",coordinate_system="image")
  attr(tracks,"aqt_clock_scope") <-
    "per_track_relative_not_global_PTS"
  attr(tracks,"aqt_raw_source_sha256") <-
    attr(x,"aqt_source_sha256")
  attr(tracks,"aqt_fish_identity_certified") <- FALSE
  attr(tracks,"aqt_3d_calibration_certified") <- FALSE
  attr(tracks,"aqt_physical_speed_certified") <- FALSE
  attr(tracks,"aqt_observations_filtered") <- sum(!keep)
  attr(tracks,"aqt_duplicate_policy") <- duplicate_policy
  tracks
}

#' Compute exploratory 2D movement steps for a legacy tracking import
#'
#' Displacements are compared ONLY within scoped track IDs, not across
#' cameras, presumed fish identities, or files. No gap interpolation
#' occurs. Image-Y is downward; atan2(-dy,dx) is an XY planar heading,
#' not anatomical fish orientation. All speeds are pixel/s.
#'
#' @param tracks Output of aqt_tracking_log_tracks().
#' @param max_gap_s Maximum interval for a valid adjacent movement step.
#' @param min_displacement_px Minimum nonzero step length for a heading.
#' @return Full row-aligned table of step length, pixel speed, dt,
#'   circular heading, valid-step flag and filename condition.
#' @export
aqt_tracking_log_motion <- function(
    tracks,max_gap_s=1,min_displacement_px=0) {
  if (!inherits(tracks,"aqt_tracks") ||
      !identical(attr(tracks,"aqt_clock_scope"),
                 "per_track_relative_not_global_PTS") ||
      !identical(attr(tracks,"aqt_units"),"px"))
    stop("Expected uncalibrated legacy tracking pixel tracks",call.=FALSE)
  if (!is.numeric(max_gap_s) || length(max_gap_s)!=1L ||
      !is.finite(max_gap_s) || max_gap_s<=0)
    stop("max_gap_s must be positive and finite",call.=FALSE)
  if (!is.numeric(min_displacement_px) ||
      length(min_displacement_px)!=1L ||
      !is.finite(min_displacement_px) || min_displacement_px<0)
    stop("min_displacement_px must be nonnegative and finite",call.=FALSE)
  n <- nrow(tracks)
  dx <- dy <- dt <- rep(NA_real_,n)
  groups <- split(seq_len(n),paste(tracks$session_id,
                                  tracks$camera_id,tracks$track_id,
                                  sep="\r"))
  for (i in groups) if(length(i)>1L) {
    dx[i[-1L]] <- diff(tracks$x[i])
    dy[i[-1L]] <- diff(tracks$y[i])
    dt[i[-1L]] <- diff(tracks$time_s[i])
  }
  valid <- is.finite(dt) & dt>0 & dt<=max_gap_s
  distance <- sqrt(dx^2+dy^2)
  speed <- rep(NA_real_,n)
  heading <- rep(NA_real_,n)
  speed[valid] <- distance[valid]/dt[valid]
  ok_heading <- valid & is.finite(distance) & distance>min_displacement_px &
                distance>0
  heading[ok_heading] <- (atan2(-dy[ok_heading],dx[ok_heading])+
    2*pi)%%(2*pi)
  result <- data.frame(
    session_id=tracks$session_id,camera_id=tracks$camera_id,
    track_id=tracks$track_id,source_file=tracks$source_file,
    source_line=tracks$source_line,time_s=tracks$time_s,
    condition=tracks$filename_phase,
    dt_s=dt,dx_px=dx,dy_px=dy,
    displacement_px=distance,speed_px_s=speed,
    heading_rad=heading,valid_step=valid,
    stringsAsFactors=FALSE)
  attr(result,"speed_unit") <- "px/s_uncalibrated"
  attr(result,"body_heading_estimated") <- FALSE
  attr(result,"independent_fish_IDs_certified") <- FALSE
  attr(result,"camera_clock_synchronization_certified") <- FALSE
  result
}

#' Reproduce the historical fixed-scale legacy tracking speed calculation
#'
#' This is for method auditing ONLY. The archived paper used 100/1920
#' nominal cm per image pixel, filtered raw estimated camera depth <200,
#' derived velocity within IDs in file row order, and retained velocities
#' >0.05 and <10 on that nominal scale. This conversion is NOT corrected
#' perspective/refraction physical velocity in cm/s.
#'
#' @param logs A log or list of imported legacy tracking logs.
#' @param nominal_cm_per_px Historical fixed image scale, explicitly
#'   supplied by analyst, default 100/1920 for SOURCE REPRODUCTION ONLY.
#' @param depth_cutoff_cm Historical source depth threshold (default 200).
#' @param speed_limits Exclusive nominal-speed range (default .05..10).
#' @return list(summary,observations) with explicit uncalibrated flags.
#' @export
aqt_tracking_legacy_replay <- function(
    logs,nominal_cm_per_px=100/1920,depth_cutoff_cm=200,
    speed_limits=c(.05,10)) {
  if (inherits(logs,"aqt_tracking_log_export")) logs <- list(logs)
  if (!is.list(logs) || !length(logs) ||
      !all(vapply(logs,inherits,logical(1L),"aqt_tracking_log_export")))
    stop("Expected one or more legacy tracking imports",call.=FALSE)
  if (!is.numeric(nominal_cm_per_px) ||
      length(nominal_cm_per_px)!=1L ||
      !is.finite(nominal_cm_per_px) || nominal_cm_per_px<=0)
    stop("nominal_cm_per_px must be positive and finite",call.=FALSE)
  if (!is.numeric(depth_cutoff_cm) ||
      length(depth_cutoff_cm)!=1L ||
      !is.finite(depth_cutoff_cm) || depth_cutoff_cm<=0)
    stop("depth_cutoff_cm must be positive and finite",call.=FALSE)
  if (!is.numeric(speed_limits) || length(speed_limits)!=2L ||
      any(!is.finite(speed_limits)) || speed_limits[1L]<0 ||
      speed_limits[2L]<=speed_limits[1L])
    stop("speed_limits must be finite increasing nonnegative bounds",
         call.=FALSE)
  originals <- lapply(logs,function(x) {
    d <- as.data.frame(x)
    d <- d[d$depth_raw_cm<depth_cutoff_cm,,drop=FALSE]
    if (!nrow(d))return(NULL)
    dx <- dy <- dt <- rep(NA_real_,nrow(d))
    groups <- split(seq_len(nrow(d)),d$fish_id)
    for (ii in groups) if(length(ii)>1L) {
      dx[ii[-1L]] <- diff(d$center_x[ii])
      dy[ii[-1L]] <- diff(d$center_y[ii])
      dt[ii[-1L]] <- diff(d$track_time_s[ii])
    }
    speed <- sqrt(dx^2+dy^2)*nominal_cm_per_px/dt
    speed[!is.finite(speed) | !is.finite(dt) | dt<=0] <- NA_real_
    good <- !is.na(speed) & speed>speed_limits[1L] &
                             speed<speed_limits[2L]
    d <- d[good,,drop=FALSE]
    d$nominal_speed <- speed[good]
    d$nominal_speed_units <- "fixed_pixel_scale_not_calibrated_cm_s"
    d
  })
  names(originals) <- vapply(logs,function(x)
    unique(x$source_file)[1L],character(1L))
  measurements <- Filter(Negate(is.null),originals)
  if (!length(measurements))
    stop("No observations survive the historical analysis filters",
         call.=FALSE)
  out <- do.call(rbind,unname(measurements))
  rownames(out) <- NULL
  keys <- unique(out$source_file)
  totals <- lapply(keys,function(k) {
    z <- out[out$source_file==k,,drop=FALSE]
    data.frame(source_file=k,filename_phase=z$filename_phase[1L],
      n_legacy_filtered=nrow(z),
      nominal_speed_mean=mean(z$nominal_speed),
      nominal_speed_sd=if(nrow(z)>1L)stats::sd(z$nominal_speed)
                       else NA_real_,
      raw_depth_mean=mean(z$depth_raw_cm),
      raw_depth_sd=if(nrow(z)>1L)stats::sd(z$depth_raw_cm)
                   else NA_real_,
      stringsAsFactors=FALSE)
  })
  summary <- do.call(rbind,totals)
  rownames(summary) <- NULL
  result <- list(summary=summary,observations=out)
  attr(result,"reconstruction_type") <-
    "historical_2d_fixed_scale_not_calibrated_3d"
  attr(result,"replicated_experimental_units_certified") <- FALSE
  attr(result,"physical_speed_cm_s_certified") <- FALSE
  attr(result,"stereo_depth_cm_is_vertical_z_certified") <- FALSE
  result
}
