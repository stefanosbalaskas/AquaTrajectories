# Scientific Core 2.0: optional, unit-aware QC sensitivity for an existing
# aqt_tracks object. This deliberately does not classify fish or infer clocks.

#' Compare explicit QC policies on an existing 2D/3D trajectory dataset
#'
#' This is a non-destructive sensitivity audit: all observed source rows remain
#' traceable in a per-policy ledger. Position coordinates, units and time are
#' taken exactly as supplied to `aqt_tracks()`. Optional frame_id, when present,
#' must increase strictly inside each scoped track. Nonadjacent acquisition
#' frames are NEVER treated as an observed movement step, even when elapsed
#' time is below a chosen threshold. It does not estimate missing positions.
#'
#' @param tracks A validated `aqt_tracks` object, in 2D image or 2D/3D tank coordinates.
#' @param gap_limits_s Finite positive maximum consecutive-step durations in seconds.
#' @param speed_limits Finite positive maximum speeds in coordinate units/s; Inf disables.
#' @param step_limits Finite positive maximum displacements in coordinate units; Inf disables.
#' @return List with `policies`, `summary` (one row per track and policy),
#'   `ledger` (one row per original input observation and policy), `source_sha256`,
#'   `units`, `dimension` and `coordinate_system`. Policy sensitivity is NOT
#'   empirical measurement accuracy or inferential uncertainty.
#' @export
aqt_qc_sensitivity <- function(tracks, gap_limits_s,
                              speed_limits=Inf, step_limits=Inf) {
  aqt_tracks_validate(tracks)
  check <- function(z,nm,allow_inf=FALSE) {
    if (!is.numeric(z) || !length(z) || anyNA(z) ||
        any(z<=0) || any(is.nan(z)) ||
        any(!is.finite(z) & !(allow_inf & is.infinite(z) & z>0)) ||
        anyDuplicated(z))
      stop(nm," must contain unique positive numeric values",call.=FALSE)
  }
  check(gap_limits_s,"gap_limits_s")
  check(speed_limits,"speed_limits",TRUE)
  check(step_limits,"step_limits",TRUE)
  policies <- expand.grid(max_gap_s=gap_limits_s,
                          max_speed=speed_limits,max_step=step_limits,
                          KEEP.OUT.ATTRS=FALSE,stringsAsFactors=FALSE)
  if (nrow(policies)>64L) stop("Maximum 64 QC policies per audit",call.=FALSE)
  policies$policy_id <- sprintf("QC%03d",seq_len(nrow(policies)))
  k <- aqt_kinematics(tracks,max_gap_s=Inf)
  n <- nrow(k)
  origin <- if ("source_row" %in% names(tracks))
    as.character(tracks$source_row) else rep(NA_character_,n)
  source_sha <- unname(digest::digest(list(
    data=as.data.frame(tracks),units=attr(tracks,"aqt_units"),
    coordinate_system=attr(tracks,"aqt_coordinate_system"),
    dimension=attr(tracks,"aqt_dimension")),algo="sha256"))
  group <- if (n) split(seq_len(n),interaction(
    k$session_id,k$camera_id,k$track_id,drop=TRUE,lex.order=TRUE)) else list()
  frame_break <- rep(FALSE,n)
  if ("frame_id" %in% names(k)) {
    ff <- k$frame_id
    if (!is.numeric(ff) || anyNA(ff) ||
        any(!is.finite(ff)) || any(ff<0) || any(ff!=floor(ff)))
      stop("frame_id must contain finite nonnegative integer-valued frames",
           call.=FALSE)
    for (ix in group) if(length(ix)>1L) {
      fd <- diff(ff[ix])
      if(any(fd<=0)) stop("frame_id must strictly increase inside each track",call.=FALSE)
      frame_break[ix[-1L]] <- fd != 1
    }
  }
  coords <- c("x","y",if(identical(attr(tracks,"aqt_dimension"),3L)) "z")
  position_ok <- if(n) k$observed & stats::complete.cases(k[,coords,drop=FALSE]) else logical()
  ledgers <- vector("list",nrow(policies))
  summaries <- vector("list",nrow(policies))
  for (j in seq_len(nrow(policies))) {
    g <- policies[j,,drop=FALSE]
    base <- is.finite(k$step_distance) & is.finite(k$speed)
    gap_bad <- base & is.finite(k$dt_s) & k$dt_s>g$max_gap_s
    speed_bad <- base & k$speed>g$max_speed
    step_bad <- base & k$step_distance>g$max_step
    ok <- base & !frame_break & !gap_bad & !speed_bad & !step_bad
    reason <- rep("eligible",n)
    reason[!base] <- "unobserved_or_first_step"
    reason[base & frame_break] <- "nonadjacent_source_frame"
    reason[base & !frame_break & gap_bad] <- "long_time_gap"
    reason[base & !frame_break & !gap_bad & speed_bad] <- "speed_threshold"
    reason[base & !frame_break & !gap_bad & !speed_bad & step_bad] <- "step_threshold"
    ledgers[[j]] <- data.frame(policy_id=g$policy_id,input_row=seq_len(n),
      source_row=origin,session_id=as.character(k$session_id),
      camera_id=as.character(k$camera_id),track_id=as.character(k$track_id),
      time_s=k$time_s,position_observed=position_ok,
      step_eligible=ok,reason=reason,
      retained_step_distance=ifelse(ok,k$step_distance,NA_real_),
      retained_step_duration_s=ifelse(ok,k$dt_s,NA_real_),
      stringsAsFactors=FALSE)
    out <- lapply(group,function(ix) {
      good <- ok[ix]
      dist <- sum(k$step_distance[ix][good]); duration <- sum(k$dt_s[ix][good])
      data.frame(policy_id=g$policy_id,session_id=as.character(k$session_id[ix[1L]]),
        camera_id=as.character(k$camera_id[ix[1L]]),
        track_id=as.character(k$track_id[ix[1L]]),
        n_source_rows=length(ix),n_observed_positions=sum(position_ok[ix]),
        n_candidate_steps=max(0L,length(ix)-1L),n_eligible_steps=sum(good),
        path_length=dist,valid_duration_s=duration,
        mean_speed=if(duration>0) dist/duration else NA_real_,
        stringsAsFactors=FALSE)
    })
    if(length(out))summaries[[j]] <- do.call(rbind,out)
  }
  ledger <- if(length(ledgers))do.call(rbind,ledgers) else data.frame()
  summary <- if(length(Filter(Negate(is.null),summaries)))
    do.call(rbind,Filter(Negate(is.null),summaries)) else data.frame()
  rownames(ledger) <- NULL
  rownames(summary) <- NULL
  stopifnot(nrow(ledger)==n*nrow(policies),
            !nrow(summary) || all(summary$n_eligible_steps<=summary$n_candidate_steps))
  result <- list(schema="AQT_SCIENTIFIC_QC_SENSITIVITY_V1",
    policies=policies,summary=summary,ledger=ledger,
    source_sha256=source_sha,
    units=attr(tracks,"aqt_units"),
    coordinate_system=attr(tracks,"aqt_coordinate_system"),
    dimension=attr(tracks,"aqt_dimension"),
    biological_accuracy_certified=FALSE)
  class(result) <- "aqt_qc_sensitivity"
  result
}

#' Export a source-linked publication figure without altering the source data
#'
#' This device wrapper accepts a zero-argument drawing function, including
#' a closure that calls an existing aqt_plot_* function. It exports identical
#' R plot commands to PNG, vector PDF, SVG and TIFF, but the physical raster
#' appearance can differ by R graphics device and operating system. Every
#' file is hashed; a new destination is required and partial outputs are
#' removed on error. Does not alter the input or infer scientific results.
#'
#' @param draw Zero-argument drawing function; should create one R base/grid plot.
#' @param directory New directory for exported figures.
#' @param formats One or more of pdf, png, svg, tiff.
#' @param width,height Physical figure dimensions in inches.
#' @param dpi Raster resolution, dots/inch.
#' @param source_file Optional existing input file to hash (never copied).
#' @param caption Optional researcher-supplied description.
#' @return New output directory invisibly.
#' @export
aqt_figure_export <- function(draw,directory,
                              formats=c("pdf","png"),width=7,height=5,
                              dpi=300L,source_file=NULL,caption="") {
  if (!is.function(draw) || length(formals(draw))!=0L)
    stop("draw must be a zero-argument plotting function",call.=FALSE)
  if (!is.character(directory) || length(directory)!=1L || is.na(directory) ||
      !nzchar(directory) || file.exists(directory) ||
      !dir.exists(dirname(directory)))
    stop("directory must be a new path in an existing parent",call.=FALSE)
  if (!is.character(formats) || !length(formats) || anyNA(formats) ||
      anyDuplicated(formats) || any(!formats %in% c("pdf","png","svg","tiff")))
    stop("formats must be unique values from pdf,png,svg,tiff",call.=FALSE)
  if (!is.numeric(width) || length(width)!=1L || !is.finite(width) ||
      width<2 || width>20 || !is.numeric(height) || length(height)!=1L ||
      !is.finite(height) || height<2 || height>20)
    stop("width and height must be 2..20 inches",call.=FALSE)
  if (!is.numeric(dpi) || length(dpi)!=1L || !is.finite(dpi) ||
      dpi!=floor(dpi) || dpi<72 || dpi>1200)
    stop("dpi must be integer 72..1200",call.=FALSE)
  if (!is.character(caption) || length(caption)!=1L || is.na(caption))
    stop("caption must be a character scalar",call.=FALSE)
  if (!is.null(source_file) && (!is.character(source_file) ||
      length(source_file)!=1L || is.na(source_file) || !file.exists(source_file) ||
      dir.exists(source_file)))
    stop("source_file must be an existing file",call.=FALSE)
  stage <- tempfile(".aqt-figure-",tmpdir=dirname(directory))
  if(!dir.create(stage)) stop("Could not create staging directory",call.=FALSE)
  on.exit(if(dir.exists(stage))unlink(stage,recursive=TRUE,force=TRUE),add=TRUE)
  for (fmt in formats) {
    path <- file.path(stage,paste0("figure.",fmt))
    if (fmt=="pdf")grDevices::pdf(path,width=width,height=height,
                                    useDingbats=FALSE)
    if (fmt=="svg")grDevices::svg(path,width=width,height=height)
    if (fmt=="png")grDevices::png(path,width=round(width*dpi),
                                    height=round(height*dpi),res=dpi)
    if (fmt=="tiff")grDevices::tiff(path,width=round(width*dpi),
                                     height=round(height*dpi),res=dpi,
                                     compression="lzw")
    tryCatch({draw()},finally=grDevices::dev.off())
    if(!file.exists(path) || is.na(file.info(path)$size) ||
       file.info(path)$size<=100L)
      stop("Figure output is missing or empty: ",fmt,call.=FALSE)
  }
  hashes <- vapply(paste0("figure.",formats),function(nm)
    unname(digest::digest(file.path(stage,nm),file=TRUE,algo="sha256")),
    character(1L))
  manifest <- list(schema="AQT_FIGURE_EXPORT_V1",formats=as.character(formats),
    width_in=width,height_in=height,dpi=dpi,caption=caption,
    source_file_sha256=if(is.null(source_file)) NULL else
      unname(digest::digest(source_file,file=TRUE,algo="sha256")),
    output_sha256=as.list(hashes),package_version=as.character(
      utils::packageVersion("aquaTrajectories")),
    source_measurement_certified=FALSE)
  jsonlite::write_json(manifest,file.path(stage,"FIGURE_MANIFEST.json"),
                       pretty=TRUE,auto_unbox=TRUE)
  if(!file.rename(stage,directory))stop("Cannot move validated output directory",call.=FALSE)
  invisible(directory)
}
