# QC 2.0 — general, explicitly unit-labelled trajectory intake and evidence.
# This extends the existing scientific QC without modifying raw observations.

#' Audit general 2D/3D trajectories with QC decisions and source-row lineage
#'
#' Data frames, CSV files and validated aqt_tracks are accepted. Source column
#' names may be mapped explicitly; milliseconds can be converted to seconds.
#' Physical mm, cm and m are converted by an explicit scale to the requested
#' analysis units, without claiming a physical calibration. Source rows are
#' retained and each accepted or rejected step links its two original rows.
#' The output contains no interpolated or identity-corrected measurements.
#'
#' @param data Data frame, CSV path, or validated aqt_tracks object.
#' @param gap_limits_s Positive finite movement-gap policies in seconds.
#' @param speed_limits Positive speed thresholds in analysis units/s; Inf disables.
#' @param step_limits Positive displacement thresholds in analysis units; Inf disables.
#' @param column_map Optional named character vector: canonical field names
#'   (track_id,time_s,x,y, plus optional session_id,camera_id,z,observed,
#'   frame_id,source_row) mapped to source column names.
#' @param units Declared source coordinates: px, mm, cm or m. Inherited from
#'   aqt_tracks if omitted.
#' @param target_units Analysis units: px, cm or m; defaults to source units,
#'   except mm converts to cm. Inherited aqt_tracks cannot be rescaled here.
#' @param coordinate_system image or tank; inherited from aqt_tracks if omitted.
#' @param time_scale Number of seconds per source time unit (e.g. .001 for ms).
#' @param session_id,camera_id Scope labels when absent from source data.
#' @return List containing canonical tracks, policy summaries, exclusion counts,
#'   full original source table, a source-to-step lineage ledger and hashes.
#' @export
aqt_qc2_report <- function(data,gap_limits_s,speed_limits=Inf,
                           step_limits=Inf,column_map=NULL,units=NULL,
                           target_units=NULL,coordinate_system=NULL,
                           time_scale=1,session_id="study",camera_id="sensor") {
  if (!is.numeric(time_scale) || length(time_scale)!=1L ||
      !is.finite(time_scale) || time_scale<=0)
    stop("time_scale must be a positive finite seconds conversion",call.=FALSE)
  from_tracks <- inherits(data,"aqt_tracks")
  from_file <- is.character(data) && length(data)==1L && !is.na(data)
  source_file_sha <- NULL
  if (from_tracks) {
    aqt_tracks_validate(data)
    if (!is.null(column_map) || !identical(time_scale,1) ||
        (!is.null(units) && !identical(units,attr(data,"aqt_units"))) ||
        (!is.null(coordinate_system) &&
         !identical(coordinate_system,attr(data,"aqt_coordinate_system"))) ||
        (!is.null(target_units) &&
         !identical(target_units,attr(data,"aqt_units"))))
      stop("Validated aqt_tracks already have fixed columns and units",call.=FALSE)
    units <- attr(data,"aqt_units")
    coordinate_system <- attr(data,"aqt_coordinate_system")
    target_units <- units
    raw <- as.data.frame(data)
  } else {
    if (from_file) {
      if (!file.exists(data) || dir.exists(data))
        stop("data must be an existing CSV file",call.=FALSE)
      source_file_sha <- unname(digest::digest(data,file=TRUE,algo="sha256"))
      # Reading identifiers as characters preserves e.g. 0007, as does
      # read.csv(..., colClasses=...) for named external identity columns.
      header <- names(utils::read.csv(data,nrows=0L,check.names=FALSE))
      map_ids <- c("session_id","camera_id","track_id","source_row")
      mapping <- if (is.null(column_map)) stats::setNames(header,header) else column_map
      id_columns <- unname(mapping[intersect(names(mapping),map_ids)])
      types <- stats::setNames(rep(NA_character_,length(header)),header)
      types[intersect(id_columns,header)] <- "character"
      raw <- utils::read.csv(data,stringsAsFactors=FALSE,
                             check.names=FALSE,colClasses=types)
    } else if (is.data.frame(data)) {
      raw <- as.data.frame(data,stringsAsFactors=FALSE)
    } else stop("data must be an aqt_tracks, data.frame or CSV path",call.=FALSE)
    if (!is.character(units) || length(units)!=1L || is.na(units) ||
        !units %in% c("px","mm","cm","m"))
      stop("Declare source units explicitly: px, mm, cm or m",call.=FALSE)
    if (!is.character(coordinate_system) || length(coordinate_system)!=1L ||
        is.na(coordinate_system) ||
        !coordinate_system %in% c("image","tank"))
      stop("Declare coordinate_system explicitly: image or tank",call.=FALSE)
    if (is.null(target_units)) target_units <- if(units=="mm")"cm" else units
    if (!is.character(target_units) || length(target_units)!=1L ||
        is.na(target_units) || !target_units %in% c("px","cm","m"))
      stop("target_units must be px, cm or m",call.=FALSE)
    if (xor(units=="px",target_units=="px") ||
        (units=="px" && coordinate_system!="image"))
      stop("Pixel and physical units cannot be interconverted",call.=FALSE)
    if (!is.null(column_map) &&
        (!is.character(column_map) || is.null(names(column_map)) ||
         anyNA(column_map) || any(!nzchar(column_map)) ||
         anyNA(names(column_map)) || any(!nzchar(names(column_map))) ||
         anyDuplicated(names(column_map)) || anyDuplicated(column_map)))
      stop("column_map must uniquely map named fields to source columns",call.=FALSE)
    allowed <- c("session_id","camera_id","track_id","time_s","x","y",
                 "z","observed","frame_id","source_row")
    if (!is.null(column_map) && any(!names(column_map) %in% allowed))
      stop("column_map contains unsupported canonical fields",call.=FALSE)
    mapping <- if (is.null(column_map))
      stats::setNames(intersect(allowed,names(raw)),
                      intersect(allowed,names(raw))) else column_map
    needed <- c("track_id","time_s","x","y")
    if (!all(needed %in% names(mapping)) ||
        any(!unname(mapping) %in% names(raw)))
      stop("Source columns are missing required mapped fields",call.=FALSE)
    canonical <- as.data.frame(stats::setNames(lapply(mapping,function(nm)raw[[nm]]),
                                      names(mapping)),stringsAsFactors=FALSE)
    if (!"session_id" %in% names(canonical)) canonical$session_id <- session_id
    if (!"camera_id" %in% names(canonical)) canonical$camera_id <- camera_id
    if (!"source_row" %in% names(canonical))
      canonical$source_row <- as.character(seq_len(nrow(canonical)))
    if (!is.numeric(canonical$time_s))
      stop("Mapped time_s must be numeric",call.=FALSE)
    canonical$time_s <- canonical$time_s*time_scale
    factor <- if(units=="px") 1 else
      c(mm=.1,cm=1,m=100)[[units]]/
      c(cm=1,m=100)[[target_units]]
    for (axis in intersect(c("x","y","z"),names(canonical))) {
      if (!is.numeric(canonical[[axis]]))
        stop("Mapped coordinates must be numeric",call.=FALSE)
      canonical[[axis]] <- canonical[[axis]]*factor
    }
    # Independently supplied observation flags must agree with coordinate
    # presence, not silently erase a nonmissing source coordinate.
    if ("observed" %in% names(canonical)) {
      if (!is.logical(canonical$observed) || anyNA(canonical$observed))
        stop("observed must be nonmissing logical",call.=FALSE)
      axes <- c("x","y",if("z" %in% names(canonical) &&
                           any(!is.na(canonical$z))) "z")
      present <- stats::complete.cases(canonical[,axes,drop=FALSE])
      if (any(canonical$observed!=present))
        stop("observed must agree with complete coordinate positions",call.=FALSE)
    }
    canonical <- canonical[,c("session_id","camera_id","track_id",
      "time_s","x","y",intersect(c("z","observed","frame_id","source_row"),
                                 names(canonical))),drop=FALSE]
    data <- aqt_tracks(canonical,units=target_units,
                       coordinate_system=coordinate_system)
  }
  if (!"source_row" %in% names(data)) {
    # Sorting makes arbitrary original row numbers unrecoverable; for a
    # preconstructed aqt_tracks object its canonical row index is declared.
    data$source_row <- as.character(seq_len(nrow(data)))
    raw$source_row <- as.character(seq_len(nrow(raw)))
  }
  data$source_row <- as.character(data$source_row)
  if (anyNA(data$source_row) || any(!nzchar(data$source_row)) ||
      anyDuplicated(data$source_row))
    stop("source_row must uniquely identify each original row",call.=FALSE)
  if(!from_tracks && !"source_row" %in% names(raw)) {
    if ("source_row" %in% names(mapping))
      raw$source_row <- as.character(raw[[mapping[["source_row"]]]])
    else raw$source_row <- as.character(seq_len(nrow(raw)))
  }
  qc <- aqt_qc_sensitivity(data,gap_limits_s=gap_limits_s,
                            speed_limits=speed_limits,
                            step_limits=step_limits)
  n <- nrow(data)
  prev <- rep(NA_integer_,n)
  if(n) {
    by_track <- split(seq_len(n),interaction(
      data$session_id,data$camera_id,data$track_id,
      drop=TRUE,lex.order=TRUE))
    for (ix in by_track) if(length(ix)>1L)
      prev[ix[-1L]] <- ix[-length(ix)]
  }
  ledger <- qc$ledger
  ix <- ledger$input_row
  ledger$from_input_row <- prev[ix]
  ledger$from_source_row <- data$source_row[prev[ix]]
  ledger$to_source_row <- data$source_row[ix]
  ledger$coordinate_units <- qc$units
  ledger$time_units <- "s"
  if("frame_id" %in% names(data))
    ledger$frame_id <- data$frame_id[ix]
  ledger$x <- data$x[ix];ledger$y <- data$y[ix]
  if(identical(qc$dimension,3L))ledger$z <- data$z[ix]
  ledger$step_status <- ifelse(ledger$step_eligible,"eligible",
    ifelse(ledger$reason=="unobserved_or_first_step","not_estimable",
           "excluded_by_policy"))
  # Do not conflate a first sample with a missing current or prior sample.
  ledger$reason_detail <- ledger$reason
  unscorable <- ledger$reason=="unobserved_or_first_step"
  first <- is.na(ledger$from_input_row)
  ledger$reason_detail[unscorable & first] <- "first_record_in_track"
  ledger$reason_detail[unscorable & !first & !ledger$position_observed] <-
    "unobserved_current_position"
  ledger$reason_detail[unscorable & !first & ledger$position_observed] <-
    "unobserved_previous_position"
  exclusions <- as.data.frame(table(ledger$policy_id,ledger$reason_detail),
                               stringsAsFactors=FALSE)
  names(exclusions) <- c("policy_id","reason","n_rows")
  exclusions <- exclusions[exclusions$n_rows>0L,,drop=FALSE]
  rownames(exclusions) <- NULL
  policy <- qc$policies
  policy$coordinate_units <- qc$units
  policy$speed_units <- paste0(qc$units,"/s")
  policy$time_units <- "s"
  summary <- qc$summary
  summary$coordinate_units <- qc$units
  summary$time_units <- "s"
  summary$n_excluded_steps <- vapply(seq_len(nrow(summary)),function(j) {
    z <- ledger$policy_id==summary$policy_id[j] &
         ledger$session_id==summary$session_id[j] &
         ledger$camera_id==summary$camera_id[j] &
         ledger$track_id==summary$track_id[j]
    sum(ledger$step_status[z]=="excluded_by_policy")
  },integer(1L))
  signature_columns <- intersect(
    c("session_id","camera_id","track_id","time_s","x","y","z",
      "observed","frame_id","source_row"),names(data))
  normalized_signature <- data[,signature_columns,drop=FALSE]
  for(axis in intersect(c("time_s","x","y","z","frame_id"),names(normalized_signature)))
    normalized_signature[[axis]] <- as.double(normalized_signature[[axis]])
  canonical_signature_sha <- unname(digest::digest(list(
    canonical=as.data.frame(normalized_signature),
    units=qc$units,coordinate_system=qc$coordinate_system,
    dimension=qc$dimension),algo="sha256"))
  result <- list(schema="AQT_QC2_GENERAL_LINEAGE_V1",
    tracks=data,raw_source=raw,policies=policy,summary=summary,
    exclusions=exclusions,lineage=ledger,
    canonical_source_sha256=canonical_signature_sha,
    raw_table_sha256=unname(digest::digest(raw,algo="sha256")),
    scientific_evidence_sha256=unname(digest::digest(list(
      tracks=data,policies=policy,summary=summary,
      exclusions=exclusions,lineage=ledger),algo="sha256")),
    source_file_sha256=source_file_sha,
    source_units=units,analysis_units=qc$units,
    seconds_per_source_time_unit=time_scale,
    coordinate_system=qc$coordinate_system,dimension=qc$dimension,
    independently_validated_accuracy=FALSE)
  class(result) <- "aqt_qc2_report"
  result
}

#' Export QC 2.0 inclusion, exclusion and lineage evidence
#'
#' Original source rows, canonical trajectories and the complete decision
#' ledger are exported separately, without overwriting existing files.
#' Manifests hash every output and reference the source input hash. This
#' is a reproducibility audit, not empirical ground-truth validation.
#'
#' @param report Output from aqt_qc2_report().
#' @param directory New output directory under an existing parent.
#' @return Output directory invisibly.
#' @export
aqt_qc2_export <- function(report,directory) {
  if (!inherits(report,"aqt_qc2_report") ||
      !identical(report$schema,"AQT_QC2_GENERAL_LINEAGE_V1"))
    stop("Expected an aqt_qc2_report",call.=FALSE)
  if (!is.character(directory) || length(directory)!=1L ||
      is.na(directory) || !nzchar(directory) || file.exists(directory) ||
      !dir.exists(dirname(directory)))
    stop("directory must be a new path in an existing parent",call.=FALSE)
  if (!identical(unname(digest::digest(report$raw_source,algo="sha256")),
                 report$raw_table_sha256))
    stop("Original source table was modified after audit",call.=FALSE)
  now <- unname(digest::digest(list(
    tracks=report$tracks,policies=report$policies,
    summary=report$summary,exclusions=report$exclusions,
    lineage=report$lineage),algo="sha256"))
  if (!identical(now,report$scientific_evidence_sha256))
    stop("QC scientific evidence was modified after audit",call.=FALSE)
  stage <- tempfile(".aqt-qc2-",tmpdir=dirname(directory))
  if(!dir.create(stage))stop("Cannot create QC staging directory",call.=FALSE)
  on.exit(if(dir.exists(stage))unlink(stage,recursive=TRUE,force=TRUE),
          add=TRUE)
  tables <- list(SOURCE_ROWS=report$raw_source,
    CANONICAL_TRACKS=as.data.frame(report$tracks),
    QC_POLICIES=report$policies,QC_SUMMARY=report$summary,
    QC_EXCLUSIONS=report$exclusions,QC_ROW_LINEAGE=report$lineage)
  for(nm in names(tables))
    utils::write.csv(tables[[nm]],file.path(stage,paste0(nm,".csv")),
                     row.names=FALSE,na="")
  writeLines(c(
    "# AquaTrajectories QC 2.0",
    "Coordinate conversions are declared in QC2_MANIFEST.json.",
    "SOURCE_ROWS contains original source-table values, not original CSV bytes.",
    "Each eligible step is tied to from_source_row and to_source_row.",
    "First steps and unobserved positions are not estimable movement steps.",
    "Frame discontinuities and threshold rejections are never interpolated.",
    "This synthetic/software audit does not independently validate fish identity or physical calibration."
  ),file.path(stage,"README.txt"),useBytes=TRUE)
  filenames <- list.files(stage)
  hashes <- as.list(stats::setNames(vapply(filenames,function(nm)
    unname(digest::digest(file.path(stage,nm),file=TRUE,algo="sha256")),
    character(1L)),filenames))
  manifest <- list(schema=report$schema,
    canonical_source_sha256=report$canonical_source_sha256,
    raw_table_sha256=report$raw_table_sha256,
    scientific_evidence_sha256=report$scientific_evidence_sha256,
    source_file_sha256=report$source_file_sha256,
    source_units=report$source_units,analysis_units=report$analysis_units,
    seconds_per_source_time_unit=report$seconds_per_source_time_unit,
    coordinate_system=report$coordinate_system,dimension=report$dimension,
    n_source_rows=nrow(report$raw_source),n_policies=nrow(report$policies),
    independent_measurement_certified=FALSE,
    output_sha256=hashes)
  jsonlite::write_json(manifest,file.path(stage,"QC2_MANIFEST.json"),
                       pretty=TRUE,auto_unbox=TRUE,null="null")
  if (!file.rename(stage,directory))
    stop("Cannot finalize QC 2.0 evidence directory",call.=FALSE)
  invisible(directory)
}
