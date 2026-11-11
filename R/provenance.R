# Provenance and manual identity correction utilities.
# MD5 detects inadvertent changes but is not a cryptographic authorization
# scheme; workflows requiring tamper-proof audit trails need stronger controls.

#' Create an immutable-input inventory for a fish-tracking analysis
#'
#' Captures path, byte size, modification time and MD5 content hash for
#' input videos, detector weights, annotations and reference truth files.
#' This does not embed the files or claim scientific reproducibility by itself.
#'
#' @param paths Existing local files to inventory.
#' @param metadata Named list of processing settings, version strings, etc.
#' @return An aqt_provenance list with files and metadata.
#' @export
aqt_provenance_new <- function(paths,metadata=list()) {
  if (!is.character(paths) || !length(paths) ||
      anyNA(paths) || any(!nzchar(paths)))
    stop("paths must be nonempty file paths",call.=FALSE)
  if (!is.list(metadata) ||
      (length(metadata) && (is.null(names(metadata)) ||
       any(!nzchar(names(metadata))))))
    stop("metadata must be a named list",call.=FALSE)
  exists <- file.exists(paths) & !dir.exists(paths)
  if (!all(exists)) stop("All provenance inputs must be existing files",call.=FALSE)
  full <- normalizePath(paths,winslash="/",mustWork=TRUE)
  if (anyDuplicated(full)) stop("Duplicate file paths",call.=FALSE)
  info <- file.info(full)
  manifest <- data.frame(path=full,bytes=as.numeric(info$size),
    mtime_utc=format(info$mtime,format="%Y-%m-%dT%H:%M:%SZ",tz="UTC"),
    md5=unname(tools::md5sum(full)),stringsAsFactors=FALSE)
  structure(list(schema_version="1.0",
    created_utc=format(Sys.time(),format="%Y-%m-%dT%H:%M:%SZ",tz="UTC"),
    files=manifest,metadata=metadata),class="aqt_provenance")
}

#' Recalculate file digests to check source integrity
#' @param provenance Object from aqt_provenance_new.
#' @return Per-file table with missing, match and changed status.
#' @export
aqt_provenance_verify <- function(provenance) {
  if (!inherits(provenance,"aqt_provenance") ||
      !is.list(provenance) || !identical(provenance$schema_version,"1.0") ||
      !is.data.frame(provenance$files) ||
      !all(c("path","bytes","md5") %in% names(provenance$files)))
    stop("Invalid provenance manifest",call.=FALSE)
  d <- provenance$files
  present <- file.exists(d$path) & !dir.exists(d$path)
  actual <- rep(NA_character_,nrow(d))
  size <- rep(NA_real_,nrow(d))
  if (any(present)) {
    actual[present] <- unname(tools::md5sum(d$path[present]))
    size[present] <- as.numeric(file.info(d$path[present])$size)
  }
  d$actual_md5 <- actual
  d$actual_bytes <- size
  d$status <- ifelse(!present,"missing",
    ifelse(!is.na(actual) & actual==d$md5 & size==d$bytes,
           "match","changed"))
  d
}

#' Apply explicitly reviewed individual identity corrections
#'
#' A correction is an instruction from a human reviewer, not an automatic
#' identity inference. Source identities are scoped by camera and session.
#' Nonoverlapping correction intervals are required for each original row.
#' The original ID remains available in original_track_id.
#'
#' @param tracks An aqt_tracks object.
#' @param corrections Data frame with session_id, camera_id,
#'   source_track_id, target_track_id, start_s, end_s, reviewer and reason.
#' @return Corrected aqt_tracks with audit columns and correction metadata.
#' @export
aqt_apply_identity_corrections <- function(tracks,corrections) {
  aqt_tracks_validate(tracks)
  required <- c("session_id","camera_id","source_track_id",
                "target_track_id","start_s","end_s","reviewer","reason")
  .aqt_required(corrections,required,"corrections")
  c <- as.data.frame(corrections)
  for (nm in c("session_id","camera_id","source_track_id","target_track_id",
               "reviewer","reason")) {
    if (anyNA(c[[nm]]) || any(!nzchar(trimws(as.character(c[[nm]])))))
      stop("Correction identifiers, reviewer and reason are required",call.=FALSE)
    c[[nm]] <- as.character(c[[nm]])
  }
  if (!is.numeric(c$start_s) || !is.numeric(c$end_s) ||
      any(!is.finite(c$start_s)) || any(!is.finite(c$end_s)) ||
      any(c$start_s>c$end_s))
    stop("Invalid identity correction interval",call.=FALSE)
  d <- as.data.frame(tracks)
  d$original_track_id <- d$track_id
  d$identity_corrected <- rep(FALSE,nrow(d))
  d$correction_id <- rep(NA_integer_,nrow(d))
  used <- rep(FALSE,nrow(d))
  for (j in seq_len(nrow(c))) {
    take <- which(d$session_id==c$session_id[j] &
      d$camera_id==c$camera_id[j] &
      d$original_track_id==c$source_track_id[j] &
      d$time_s>=c$start_s[j] & d$time_s<=c$end_s[j])
    if (!length(take))
      stop("Correction does not match any source observations: ",j,call.=FALSE)
    if (any(used[take]))
      stop("Overlapping correction intervals for source observations",call.=FALSE)
    used[take] <- TRUE
    d$track_id[take] <- c$target_track_id[j]
    d$identity_corrected[take] <- TRUE
    d$correction_id[take] <- j
  }
  out <- aqt_tracks(d,units=attr(tracks,"aqt_units"),
                     coordinate_system=attr(tracks,"aqt_coordinate_system"))
  attr(out,"aqt_correction_log") <- c
  out
}
