#' Import a versioned Python-to-R aquatic tracking research bundle
#'
#' Research Bundle v1 accepts externally produced YOLO/ByteTrack,
#' YOLO/BoT-SORT and idtracker.ai tracks in the same audit-checked schema.
#' Recorded timestamps are never inferred from nominal FPS. Where time
#' status is unknown, raw observations remain available but \code{tracks}
#' is NULL and time-based scientific analysis is intentionally blocked.
#'
#' @param directory Completed Research Bundle v1 directory.
#' @return An \code{aqt_research_bundle} list with \code{observations},
#'   \code{frames}, \code{tracks} (or NULL), \code{metadata} and provenance.
#' @export
aqt_research_bundle_import <- function(directory) {
  if (!is.character(directory) || length(directory)!=1L ||
      is.na(directory) || !dir.exists(directory))
    stop("Existing research bundle directory required", call.=FALSE)
  root <- normalizePath(directory, winslash="/", mustWork=TRUE)
  items <- file.path(root,c("frames.csv","observations.csv","manifest.json"))
  if (!all(file.exists(items)) || any(dir.exists(items)))
    stop("Incomplete Research Bundle v1: frames/observations/manifest missing",call.=FALSE)
  meta <- jsonlite::fromJSON(paste(readLines(items[3L],warn=FALSE,encoding="UTF-8"),
                                   collapse="\n"),simplifyVector=FALSE)
  if (!identical(meta$schema_version,"1.0.0") ||
      !identical(meta$coordinate_units,"px") ||
      !identical(meta$coordinate_system,"image") ||
      !meta$time_status %in% c("source_pts","externally_verified","unverified","unknown") ||
      !isFALSE(meta$fish_identity_accuracy_certified) ||
      !isFALSE(meta$cross_camera_identity_certified) ||
      !isFALSE(meta$underwater_calibration_certified))
    stop("Unsupported or misleading research bundle metadata",call.=FALSE)
  for (name in c("frames.csv","observations.csv")) {
    expected <- meta$output_sha256[[name]]
    if (!is.character(expected) || length(expected)!=1L ||
        !grepl("^[a-f0-9]{64}$",expected) ||
        !identical(unname(digest::digest(file.path(root,name),
                                        algo="sha256",file=TRUE)),expected))
      stop("Research bundle integrity mismatch: ",name,call.=FALSE)
  }
  frame_cols <- c("session_id","camera_id","frame_id","time_s","width_px","height_px")
  obs_cols <- c("session_id","camera_id","track_id","frame_id","time_s",
                "x","y","observed","quality_flag","position_definition",
                "bbox_left","bbox_top","bbox_width","bbox_height",
                "detection_confidence","identity_probability","source_row")
  frames <- utils::read.csv(items[1L],stringsAsFactors=FALSE,
                            colClasses=c(session_id="character",camera_id="character"),
                            na.strings="")
  obs <- utils::read.csv(items[2L],stringsAsFactors=FALSE,
                         colClasses=c(session_id="character",camera_id="character",
                                      track_id="character",quality_flag="character",
                                      position_definition="character"),
                         na.strings="")
  if (!identical(names(frames),frame_cols) || !identical(names(obs),obs_cols))
    stop("Unexpected Research Bundle v1 CSV headers",call.=FALSE)
  numeric_fields <- c("frame_id","time_s","width_px","height_px")
  for (nm in numeric_fields) {
    if (is.logical(frames[[nm]]) && all(is.na(frames[[nm]])))
      frames[[nm]] <- as.numeric(frames[[nm]])
  }
  for (nm in c("frame_id","time_s","x","y","bbox_left","bbox_top",
               "bbox_width","bbox_height","detection_confidence",
               "identity_probability","source_row")) {
    if (is.logical(obs[[nm]]) && all(is.na(obs[[nm]])))
      obs[[nm]] <- as.numeric(obs[[nm]])
  }
  if (!is.numeric(meta$n_frames) || length(meta$n_frames)!=1L ||
      !is.numeric(meta$n_observations) || length(meta$n_observations)!=1L ||
      nrow(frames)!=meta$n_frames || nrow(obs)!=meta$n_observations ||
      !nrow(frames))
    stop("Incorrect bundle row counts",call.=FALSE)
  if (!is.character(meta$session_id) || length(meta$session_id)!=1L ||
      !nzchar(meta$session_id) ||
      !is.character(meta$camera_id) || length(meta$camera_id)!=1L ||
      !nzchar(meta$camera_id) ||
      anyNA(frames$session_id) || anyNA(frames$camera_id) ||
      any(frames$session_id!=meta$session_id) ||
      any(frames$camera_id!=meta$camera_id) ||
      anyNA(obs$session_id) || anyNA(obs$camera_id) ||
      any(obs$session_id!=meta$session_id) ||
      any(obs$camera_id!=meta$camera_id))
    stop("Bundle scope mismatch",call.=FALSE)
  required_num <- c("frame_id","width_px","height_px")
  if (!all(vapply(frames[required_num],is.numeric,logical(1L))) ||
      any(!is.finite(as.matrix(frames[required_num]))) ||
      any(frames$frame_id<0 | frames$frame_id!=floor(frames$frame_id)) ||
      any(frames$width_px<1 | frames$height_px<1) ||
      any(frames$width_px!=floor(frames$width_px)) ||
      any(frames$height_px!=floor(frames$height_px)) ||
      anyDuplicated(frames$frame_id) ||
      (nrow(frames)>1L && any(diff(frames$frame_id)<=0)))
    stop("Invalid source-frame manifest",call.=FALSE)
  if (!is.numeric(frames$time_s) ||
      (meta$time_status=="unknown" && any(!is.na(frames$time_s))) ||
      (meta$time_status!="unknown" &&
       (any(!is.finite(frames$time_s)) ||
        any(frames$time_s<0) ||
        (nrow(frames)>1L && any(diff(frames$time_s)<=0)))))
    stop("Frame timing contradicts declared time provenance",call.=FALSE)
  for (nm in c("frame_id","time_s","x","y","source_row",
               "bbox_left","bbox_top","bbox_width","bbox_height",
               "detection_confidence","identity_probability")) {
    if (!is.numeric(obs[[nm]]))
      stop("Non-numeric observation column: ",nm,call.=FALSE)
    if (any(is.infinite(obs[[nm]])))
      stop("Nonfinite observation value: ",nm,call.=FALSE)
  }
  if (anyNA(obs$frame_id) ||
      any(obs$frame_id<0 | obs$frame_id!=floor(obs$frame_id)) ||
      anyNA(obs$source_row) || any(obs$source_row<1 | obs$source_row!=floor(obs$source_row)) ||
      anyNA(obs$track_id) || any(!nzchar(obs$track_id)))
    stop("Missing frame/source-row or invalid track identity",call.=FALSE)
  idx <- match(obs$frame_id,frames$frame_id)
  if (anyNA(idx))
    stop("Observation references an absent source frame",call.=FALSE)
  if (meta$time_status=="unknown") {
    if (any(!is.na(obs$time_s)))
      stop("Unknown time cannot contain invented observation seconds",call.=FALSE)
  } else if (anyNA(obs$time_s) ||
             any(abs(obs$time_s-frames$time_s[idx])>1e-8)) {
    stop("Observation time does not match recorded frame time",call.=FALSE)
  }
  if (!is.logical(obs$observed) || anyNA(obs$observed) ||
      any(xor(is.na(obs$x),is.na(obs$y))) ||
      any(obs$observed != (!is.na(obs$x) & !is.na(obs$y))) ||
      any(!obs$quality_flag %in% c("unreviewed","source_missing_position")) ||
      any(!obs$position_definition %in% c("bbox_center","source_xy")) ||
      anyDuplicated(paste(obs$frame_id,obs$track_id,sep="\r")))
    stop("Invalid observed flags, quality flags or scoped identities",call.=FALSE)
  has_xy <- which(obs$observed)
  if (length(has_xy) &&
      (any(obs$x[has_xy]<0 | obs$x[has_xy]>frames$width_px[idx[has_xy]]) ||
       any(obs$y[has_xy]<0 | obs$y[has_xy]>frames$height_px[idx[has_xy]])))
    stop("Observed fish point is outside image frame",call.=FALSE)
  bb <- c("bbox_left","bbox_top","bbox_width","bbox_height")
  present <- !is.na(as.matrix(obs[bb]))
  if (any(rowSums(present) %in% 1:3))
    stop("Incomplete bounding box",call.=FALSE)
  if (any(rowSums(present)==4L)) {
    k <- which(rowSums(present)==4L)
    if (any(obs$bbox_left[k]<0 | obs$bbox_top[k]<0 |
            obs$bbox_width[k]<=0 | obs$bbox_height[k]<=0 |
            obs$bbox_left[k]+obs$bbox_width[k]>frames$width_px[idx[k]]+1e-7 |
            obs$bbox_top[k]+obs$bbox_height[k]>frames$height_px[idx[k]]+1e-7))
      stop("Invalid bounding box",call.=FALSE)
  }
  for (nm in c("detection_confidence","identity_probability")) {
    v <- obs[[nm]]
    if (any(!is.na(v) & (v<0 | v>1)))
      stop("Confidence/probability outside [0,1]",call.=FALSE)
  }
  tracks <- NULL
  if (meta$time_status!="unknown") {
    d <- obs
    d$observed <- obs$observed
    tracks <- aqt_tracks(d,units="px",coordinate_system="image")
    attr(tracks,"aqt_time_provenance") <- meta$time_status
    attr(tracks,"aqt_independent_identity_certified") <- FALSE
  }
  structure(list(
    observations=obs,frames=frames,tracks=tracks,metadata=meta,
    directory=root,output_sha256_verified=TRUE,
    clock_verification_evidence_declared=identical(meta$time_status,"externally_verified"),
    clock_independently_verified=FALSE,
    biological_identity_certified=FALSE
  ),class="aqt_research_bundle")
}

#' Export an unchanged, verified research bundle without losing provenance
#'
#' Byte-preserving export intentionally does not silently reserialize a
#' scientific dataset. To alter observations, create a new versioned bundle
#' with independently declared provenance and a new checksum manifest.
#'
#' @param bundle Imported \code{aqt_research_bundle}.
#' @param directory New, nonexistent output directory.
#' @return Output directory invisibly.
#' @export
aqt_research_bundle_export <- function(bundle,directory) {
  if (!inherits(bundle,"aqt_research_bundle") ||
      !isTRUE(bundle$output_sha256_verified))
    stop("Expected a validated Research Bundle v1",call.=FALSE)
  if (!is.character(directory) || length(directory)!=1L || is.na(directory) ||
      dir.exists(directory) || file.exists(directory) ||
      !dir.exists(dirname(directory)))
    stop("Export destination must be new, with an existing parent",call.=FALSE)
  # Re-validate the actual source bytes just before copying.
  original <- aqt_research_bundle_import(bundle$directory)
  if (!identical(original$metadata$output_sha256,bundle$metadata$output_sha256))
    stop("Bundle provenance changed after import",call.=FALSE)
  temp <- tempfile(".aqt-research-export-",tmpdir=dirname(directory))
  dir.create(temp)
  on.exit(unlink(temp,recursive=TRUE,force=TRUE),add=TRUE)
  names <- c("frames.csv","observations.csv","manifest.json")
  if (!all(file.copy(file.path(bundle$directory,names),file.path(temp,names))))
    stop("Could not copy complete research bundle",call.=FALSE)
  aqt_research_bundle_import(temp)
  if (!file.rename(temp,directory))
    stop("Could not commit byte-preserved research bundle",call.=FALSE)
  invisible(directory)
}
