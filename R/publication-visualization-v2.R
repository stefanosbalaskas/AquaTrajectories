# Publication Visualization 2.0. All plots here are conditional on supplied,
# observed 2D/3D coordinates and explicit QC 2.0 movement eligibility.
# No missing position, frame or clock interval is interpolated or invented.

.aqt_viz2_sha <- function(object) unname(digest::digest(object,algo="sha256"))
.aqt_viz2_file_sha <- function(path) unname(digest::digest(path,file=TRUE,algo="sha256"))
.aqt_viz2_spec_sha <- function(spec) .aqt_viz2_sha(
  unclass(spec)[setdiff(names(spec),"integrity_sha256")])

.aqt_viz2_check_qc <- function(report) {
  if(!inherits(report,"aqt_qc2_report") ||
     !identical(report$schema,"AQT_QC2_GENERAL_LINEAGE_V1"))
    stop("Expected a QC 2.0 report",call.=FALSE)
  expected <- .aqt_viz2_sha(list(
    tracks=report$tracks,policies=report$policies,summary=report$summary,
    exclusions=report$exclusions,lineage=report$lineage))
  if(!identical(expected,report$scientific_evidence_sha256) ||
     !identical(.aqt_viz2_sha(report$raw_source),
                report$raw_table_sha256))
    stop("QC 2.0 report modified after scientific audit",call.=FALSE)
  aqt_tracks_validate(report$tracks)
  invisible(TRUE)
}

#' Retrieve reproducible generic manuscript figure presets
#'
#' Presets are editorial starting points, NOT claims of compliance with a
#' specific journal's current artwork instructions. Check the actual guide.
#' Raster output dpi may differ between journals; SVG and PDF stay vector.
#' @return Data frame with preset name, inches, raster dpi and point size.
#' @export
aqt_viz2_presets <- function() {
  data.frame(
    preset=c("journal_single","journal_double","manuscript","presentation"),
    width_in=c(3.5,7.2,6.8,12),
    height_in=c(3.3,4.8,4.8,6.75),
    dpi=c(600L,300L,300L,150L),
    pointsize=c(9,12,11,16),
    stringsAsFactors=FALSE)
}

#' Inventory the entire public native and optional 3D plot gallery
#'
#' Reads the package's live public namespace, so new aqt_plot_* exports
#' cannot silently disappear from the inventory. Execute all renderers with
#' scripts/viz2_gallery_matrix.R to check real output and 3D scene geometry.
#' @return Exactly one row per public aqt_plot_* renderer, or an error.
#' @export
aqt_viz2_gallery <- function() {
  native <- sort(grep("^aqt_plot_",getNamespaceExports("aquaTrajectories"),
                      value=TRUE))
  scenes <- c("aqt_plot_path3d","aqt_plot_ensemble3d",
     "aqt_plot_joint_scene_cloud3d","aqt_plot_school3d",
     "aqt_plot_tank_scene3d","aqt_plot_voxel3d")
  if(length(native)!=22L || anyDuplicated(native) ||
     !all(scenes %in% native))
    stop("Public plot inventory changed: review gallery fixtures",call.=FALSE)
  data.frame(
    function_name=native,
    backend=ifelse(native %in% scenes,"rgl_scene","base_or_grid"),
    gallery_chunk=paste0("gallery-plot-",
                         gsub("_","-",sub("^aqt_plot_","",native))),
    optional_backend=native %in% scenes,
    stringsAsFactors=FALSE)
}

.aqt_viz2_validate_spec <- function(spec) {
  if(!inherits(spec,"aqt_viz2_spec") ||
     !identical(spec$schema,"AQT_PUBLICATION_VISUALIZATION_V2") ||
     !identical(.aqt_viz2_spec_sha(spec),spec$integrity_sha256))
    stop("Figure specification modified after its source-linked audit",
         call.=FALSE)
  if(!identical(.aqt_viz2_sha(spec$points),
                spec$provenance$plotted_points_sha256) ||
     !identical(.aqt_viz2_sha(spec$segments),
                spec$provenance$eligible_segments_sha256) ||
     !identical(.aqt_viz2_sha(spec$qc_decisions),
                spec$provenance$qc_decisions_sha256))
    stop("Figure points or QC decisions modified",call.=FALSE)
  if(!is.null(spec$source_file)) {
    if(!file.exists(spec$source_file) ||
       !identical(.aqt_viz2_file_sha(spec$source_file),
                  spec$provenance$source_file_sha256))
      stop("Referenced source file changed after specification",call.=FALSE)
  }
  invisible(TRUE)
}

#' Construct a source-linked, gap-aware publication figure specification
#'
#' Use either validated aqt_tracks with a *declared finite gap_limit_s*, or
#' an existing QC 2.0 report with an explicit policy_id when multiple policies
#' were audited. Trajectory positions remain visible as original samples,
#' while line segments and speed points derive solely from eligible
#' consecutive QC movement steps; neither missing nor excluded steps connect.
#' For 3D data, xz and yz are explicitly 2D projections, not 3D scenes.
#' Position coordinates must be comparable within one session/camera scope.
#'
#' @param data aqt_tracks or an unmodified aqt_qc2_report.
#' @param figure paths, speed, qc_coverage or qc_reasons.
#' @param gap_limit_s Finite positive maximum intersample time (seconds),
#'   required for raw aqt_tracks; an existing QC 2.0 report owns its policies.
#' @param policy_id Exact QC policy ID; required if report has >1 policy.
#' @param session_id,camera_id Optional scope selectors, mandatory for
#'   multi-session or multi-camera input.
#' @param plane xy, xz or yz. Non-xy planes require actual 3D tank input.
#' @param preset Generic figure size/dpi preset from aqt_viz2_presets().
#' @param caption Researcher-supplied descriptive caption.
#' @param source_file Optional immutable existing source CSV/data file; SHA-256
#'   recorded and checked at export, and must match a QC2 CSV source digest.
#' @return Sealed aqt_viz2_spec with original row IDs, eligible segments,
#'   all QC decisions, plot source hashes, units, and figure metadata.
#' @export
aqt_viz2_spec <- function(data,figure=c("paths","speed","qc_coverage","qc_reasons"),
                          gap_limit_s=NULL,policy_id=NULL,
                          session_id=NULL,camera_id=NULL,
                          plane=c("xy","xz","yz"),
                          preset="journal_double",caption="",source_file=NULL) {
  figure <- match.arg(figure)
  plane <- match.arg(plane)
  standards <- aqt_viz2_presets()
  if(!is.character(preset)||length(preset)!=1L||is.na(preset)||
     !preset %in% standards$preset)
    stop("Unknown publication preset",call.=FALSE)
  if(!is.character(caption)||length(caption)!=1L||is.na(caption))
    stop("caption must be one character string",call.=FALSE)
  if(inherits(data,"aqt_qc2_report")) {
    if(!is.null(gap_limit_s))
      stop("QC 2.0 report already owns its gap policies",call.=FALSE)
    report <- data
  } else if(inherits(data,"aqt_tracks")) {
    aqt_tracks_validate(data)
    if(!is.numeric(gap_limit_s)||length(gap_limit_s)!=1L ||
       !is.finite(gap_limit_s)||gap_limit_s<=0)
      stop("Declare a finite positive gap_limit_s for unreviewed tracks",
           call.=FALSE)
    report <- aqt_qc2_report(data,gap_limits_s=gap_limit_s)
  } else stop("data must be validated tracks or a QC 2.0 report",call.=FALSE)
  .aqt_viz2_check_qc(report)
  if(is.null(policy_id)) {
    if(nrow(report$policies)!=1L)
      stop("Select an explicit policy_id from the QC 2.0 sensitivity audit",
           call.=FALSE)
    policy_id <- as.character(report$policies$policy_id[1L])
  }
  if(!is.character(policy_id)||length(policy_id)!=1L ||
     is.na(policy_id)||!policy_id %in% report$policies$policy_id)
    stop("policy_id not present in the QC 2.0 report",call.=FALSE)
  tr <- report$tracks
  if(!nrow(tr))stop("Cannot plot an empty trajectory dataset",call.=FALSE)
  pairs <- unique(data.frame(session_id=as.character(tr$session_id),
                             camera_id=as.character(tr$camera_id)))
  if(is.null(session_id)) {
    if(length(unique(pairs$session_id))!=1L)
      stop("Specify session_id for multiple independent sessions",call.=FALSE)
    session_id <- pairs$session_id[1L]
  }
  if(is.null(camera_id)) {
    cams <- unique(pairs$camera_id[pairs$session_id==session_id])
    if(length(cams)!=1L)
      stop("Specify camera_id to avoid mixing independent image views",
           call.=FALSE)
    camera_id <- cams[1L]
  }
  for(z in list(session_id,camera_id))
    if(!is.character(z)||length(z)!=1L||is.na(z)||!nzchar(z))
      stop("session_id and camera_id must be nonempty strings",call.=FALSE)
  chosen <- as.character(tr$session_id)==session_id &
            as.character(tr$camera_id)==camera_id
  if(!any(chosen))stop("Selected session/camera has no rows",call.=FALSE)
  if(plane!="xy" && !identical(report$dimension,3L))
    stop("xz/yz projection requires true 3D coordinates",call.=FALSE)
  if(plane!="xy" && report$coordinate_system!="tank")
    stop("Depth projections require a tank coordinate system",call.=FALSE)
  axes <- strsplit(plane,"",fixed=TRUE)[[1L]]
  observations <- as.data.frame(tr[chosen,,drop=FALSE])
  points <- data.frame(source_row=as.character(observations$source_row),
    session_id=as.character(observations$session_id),
    camera_id=as.character(observations$camera_id),
    track_id=as.character(observations$track_id),
    time_s=observations$time_s,
    x=observations[[axes[1L]]],y=observations[[axes[2L]]],
    observed=observations$observed &
      stats::complete.cases(observations[,axes,drop=FALSE]),
    stringsAsFactors=FALSE)
  if("frame_id" %in% names(observations))
    points$frame_id <- observations$frame_id
  ledger <- report$lineage
  ledger <- ledger[ledger$policy_id==policy_id &
      as.character(ledger$session_id)==session_id &
      as.character(ledger$camera_id)==camera_id,,drop=FALSE]
  if(nrow(ledger)!=nrow(points) ||
     !setequal(as.character(ledger$to_source_row),points$source_row))
    stop("QC ledger does not reconcile with plotted source rows",call.=FALSE)
  # Source-row IDs provide exact original predecessor/successor linkage.
  ok <- which(ledger$step_eligible)
  ii <- match(as.character(ledger$from_source_row[ok]),points$source_row)
  jj <- match(as.character(ledger$to_source_row[ok]),points$source_row)
  if(anyNA(ii)||anyNA(jj)||any(!points$observed[ii] | !points$observed[jj]))
    stop("Eligible movement lacks matching observed source endpoints",
         call.=FALSE)
  if(any(points$track_id[ii]!=points$track_id[jj]) ||
     any(points$time_s[ii]>=points$time_s[jj]))
    stop("Eligible movements must be within fish and forward in time",
         call.=FALSE)
  segments <- data.frame(
    policy_id=rep(policy_id,length(ok)),
    track_id=points$track_id[jj],
    from_source_row=points$source_row[ii],
    to_source_row=points$source_row[jj],
    from_time_s=points$time_s[ii],time_s=points$time_s[jj],
    x0=points$x[ii],y0=points$y[ii],
    x1=points$x[jj],y1=points$y[jj],
    full_step_distance=ledger$retained_step_distance[ok],
    dt_s=ledger$retained_step_duration_s[ok],
    stringsAsFactors=FALSE)
  segments$speed <- segments$full_step_distance/segments$dt_s
  if(any(!is.finite(segments$speed))||any(segments$dt_s<=0))
    stop("Eligible QC steps have invalid distance/time denominators",
         call.=FALSE)
  if(figure=="paths" && !any(points$observed))
    stop("No observed positions to plot",call.=FALSE)
  if(figure=="speed" && !nrow(segments))
    stop("No eligible speed observations for selected QC policy",
         call.=FALSE)
  if(figure=="qc_coverage" &&
     length(unique(points$track_id))>30L)
    stop("QC coverage panel supports at most 30 fish; select a scope",
         call.=FALSE)
  if(!is.null(source_file)) {
    if(!is.character(source_file)||length(source_file)!=1L||
       is.na(source_file)||!file.exists(source_file)||
       dir.exists(source_file))
      stop("source_file must be an existing data file",call.=FALSE)
    source_hash <- .aqt_viz2_file_sha(source_file)
    if(!is.null(report$source_file_sha256) &&
       !identical(source_hash,report$source_file_sha256))
      stop("source_file does not match QC 2.0 input file hash",call.=FALSE)
  } else source_hash <- report$source_file_sha256
  standard <- standards[standards$preset==preset,,drop=FALSE]
  provenance <- list(
    source_file_sha256=source_hash,
    raw_table_sha256=report$raw_table_sha256,
    canonical_source_sha256=report$canonical_source_sha256,
    qc_scientific_evidence_sha256=report$scientific_evidence_sha256,
    plotted_points_sha256=.aqt_viz2_sha(points),
    eligible_segments_sha256=.aqt_viz2_sha(segments),
    qc_decisions_sha256=.aqt_viz2_sha(ledger),
    coordinate_units=report$analysis_units,
    original_coordinate_units=report$source_units,
    time_units="s",
    coordinate_system=report$coordinate_system,
    dimension=report$dimension,
    source_clock_physically_validated=FALSE,
    independently_certified_biological_accuracy=FALSE)
  spec <- list(schema="AQT_PUBLICATION_VISUALIZATION_V2",
    figure=figure,plane=plane,policy_id=policy_id,
    session_id=session_id,camera_id=camera_id,
    caption=caption,source_file=source_file,
    preset=standard,
    policy=report$policies[report$policies$policy_id==policy_id,,drop=FALSE],
    points=points,segments=segments,qc_decisions=ledger,
    counts=list(n_source_rows=nrow(points),
      n_observed_positions=sum(points$observed),
      n_eligible_steps=nrow(segments),
      n_policy_excluded=sum(ledger$step_status=="excluded_by_policy"),
      n_not_estimable=sum(ledger$step_status=="not_estimable")),
    provenance=provenance)
  class(spec) <- "aqt_viz2_spec"
  spec$integrity_sha256 <- .aqt_viz2_spec_sha(spec)
  .aqt_viz2_validate_spec(spec)
  spec
}

.aqt_viz2_range <- function(x) {
  x <- x[is.finite(x)]
  if(!length(x))stop("No finite values for plot axis",call.=FALSE)
  out <- range(x)
  pad <- if(diff(out)>0)diff(out)*.06 else max(1,abs(out[1L])*.08)
  out+c(-pad,pad)
}

#' Draw a QC-aware publication specification on the current R graphics device
#'
#' This renders only the audited, sealed figure specification. The plot does
#' not create an external file; use aqt_viz2_export for hash-linked artifacts.
#' Spatial paths connect ONLY explicitly eligible QC2 source-row pairs;
#' failed steps are not joined by any line, even if source points exist.
#' Speed is the full original Euclidean step length / elapsed seconds; xz/yz
#' projections do not silently change the velocity denominator.
#'
#' @param spec Source-linked aqt_viz2_spec.
#' @return The specification invisibly, after drawing on the current device.
#' @export
aqt_viz2_draw <- function(spec) {
  .aqt_viz2_validate_spec(spec)
  pp <- spec$points
  ss <- spec$segments
  ledger <- spec$qc_decisions
  name <- paste(spec$session_id,spec$camera_id,sep="/")
  id <- sort(unique(pp$track_id))
  col <- grDevices::hcl.colors(length(id),"Dark 3")
  names(col) <- id
  coords <- spec$provenance$coordinate_units
  old <- graphics::par(no.readonly=TRUE)
  on.exit(graphics::par(old),add=TRUE)
  graphics::par(bg="white",mar=c(4.5,4.8,3.25,1.1),
     cex.axis=.83,cex.lab=.95,cex.main=1,
     ps=spec$preset$pointsize[[1L]])
  if(spec$figure=="paths") {
    pts <- pp[pp$observed,,drop=FALSE]
    ylim <- .aqt_viz2_range(pts$y)
    if(spec$plane=="xy" &&
       spec$provenance$coordinate_system=="image") ylim <- rev(ylim)
    graphics::plot(NA_real_,NA_real_,
      xlim=.aqt_viz2_range(pts$x),ylim=ylim,asp=1,
      xlab=paste0(toupper(substr(spec$plane,1L,1L))," (",coords,")"),
      ylab=paste0(toupper(substr(spec$plane,2L,2L))," (",coords,")"),
      main=paste0("Observed QC-qualified paths (",spec$plane,")"))
    if(nrow(ss)) for(j in seq_len(nrow(ss)))
      graphics::segments(ss$x0[j],ss$y0[j],ss$x1[j],ss$y1[j],
        col=col[[ss$track_id[j]]],lwd=1.25)
    for(k in id) {
      v <- pts$track_id==k
      graphics::points(pts$x[v],pts$y[v],col=col[[k]],pch=16,cex=.55)
    }
    graphics::mtext(paste0("Source points ",spec$counts$n_observed_positions,
      "; qualified adjacent steps ",spec$counts$n_eligible_steps,
      "; QC policy ",spec$policy_id),side=3,line=.1,cex=.58)
  } else if(spec$figure=="speed") {
    graphics::plot(NA_real_,NA_real_,
      xlim=.aqt_viz2_range(ss$time_s),
      ylim=.aqt_viz2_range(c(0,ss$speed)),
      xlab="Source time (s)",ylab=paste0("Speed (",coords,"/s)"),
      main="Speed from eligible observed steps")
    for(k in id) {
      v <- ss$track_id==k
      if(any(v))graphics::points(ss$time_s[v],ss$speed[v],
                                 pch=16,cex=.65,col=col[[k]])
    }
    graphics::mtext(paste0("No interpolation, no speed estimates from rejected steps; ",
                           spec$policy_id),side=3,line=.1,cex=.60)
  } else if(spec$figure=="qc_coverage") {
    n <- vapply(id,function(k)sum(pp$track_id==k),integer(1L))
    elig <- vapply(id,function(k)sum(ledger$track_id==k &
        ledger$step_status=="eligible"),integer(1L))
    rej <- vapply(id,function(k)sum(ledger$track_id==k &
        ledger$step_status=="excluded_by_policy"),integer(1L))
    not <- n-elig-rej
    values <- rbind(eligible=elig,policy_excluded=rej,not_estimable=not)
    graphics::barplot(values,col=c("#1F6D75","#C07C4C","#929CA4"),
      names.arg=id,las=2,ylab="Source rows",
      main=paste("QC coverage",name),cex.names=.68)
    graphics::legend("topright",legend=rownames(values),
      fill=c("#1F6D75","#C07C4C","#929CA4"),bty="n",cex=.7)
    graphics::mtext(paste("All source rows retained;",spec$policy_id),
      side=3,line=.1,cex=.59)
  } else {
    levels <- sort(unique(as.character(ledger$reason_detail)))
    t <- table(factor(ledger$reason_detail,levels=levels))
    graphics::barplot(t,las=2,col="#286B80",border=NA,
      cex.names=.65,ylab="Source rows",
      main=paste("QC decisions",name))
    graphics::mtext(paste("Reasons are per source row;",spec$policy_id),
      side=3,line=.1,cex=.59)
  }
  invisible(spec)
}

#' Export audited publication figures and exact plotted-data evidence
#'
#' Creates PDF/SVG vectors and PNG/TIFF raster files through the existing
#' figure exporter. Journal presets supply physical size and dpi. Uses a
#' transaction-staged, non-overwriting directory and SHA-256 manifest linking
#' both original scientific evidence and every exported output to exact
#' plotted points, eligible movements, and QC source-row decisions.
#' Device bytes, fonts and anti-aliasing can vary across operating systems;
#' byte-identical cross-OS PDF/SVG/TIFF files are NOT claimed.
#'
#' @param spec Validated, unmodified aqt_viz2_spec.
#' @param directory New output directory under an existing parent.
#' @param formats Unique selected formats pdf,svg,png,tiff.
#' @return New output directory invisibly; no outputs on failure.
#' @export
aqt_viz2_export <- function(spec,directory,
                            formats=c("pdf","svg","png","tiff")) {
  .aqt_viz2_validate_spec(spec)
  if(!is.character(directory)||length(directory)!=1L||is.na(directory)||
     !nzchar(directory)||file.exists(directory)||
     !dir.exists(dirname(directory)))
    stop("directory must be a new path in an existing parent",call.=FALSE)
  standard <- spec$preset[1L,,drop=FALSE]
  stage <- tempfile(".aqt-viz2-stage-",tmpdir=dirname(directory))
  on.exit(if(dir.exists(stage))unlink(stage,recursive=TRUE,force=TRUE),
          add=TRUE)
  aqt_figure_export(
    draw=function()aqt_viz2_draw(spec),directory=stage,
    formats=formats,width=standard$width_in,height=standard$height_in,
    dpi=standard$dpi,source_file=spec$source_file,caption=spec$caption)
  save_csv <- function(x,path)
    utils::write.csv(x,file.path(stage,path),row.names=FALSE,na="")
  save_csv(spec$points,"PLOTTED_SOURCE_POINTS.csv")
  save_csv(spec$segments,"ELIGIBLE_SOURCE_SEGMENTS.csv")
  save_csv(spec$qc_decisions,"ALL_QC_ROW_DECISIONS.csv")
  save_csv(spec$policy,"SELECTED_QC_POLICY.csv")
  # Files above are the actual R data used to render this figure. The hashed
  # source report raw/canonical inputs may include additional external rows.
  support <- c(paste0("figure.",formats),"FIGURE_MANIFEST.json",
     "PLOTTED_SOURCE_POINTS.csv","ELIGIBLE_SOURCE_SEGMENTS.csv",
     "ALL_QC_ROW_DECISIONS.csv","SELECTED_QC_POLICY.csv")
  hashes <- stats::setNames(vapply(support,function(path)
      .aqt_viz2_file_sha(file.path(stage,path)),character(1L)),support)
  manifest <- list(
    schema="AQT_PUBLICATION_VISUALIZATION_V2_EVIDENCE",
    figure=spec$figure,plane=spec$plane,
    session_id=spec$session_id,camera_id=spec$camera_id,
    policy_id=spec$policy_id,
    preset=as.list(standard[1L,,drop=FALSE]),
    formats=formats,caption=spec$caption,
    counts=spec$counts,
    data_provenance=spec$provenance,
    plot_spec_sha256=spec$integrity_sha256,
    output_sha256=as.list(hashes),
    package_version=as.character(utils::packageVersion("aquaTrajectories")),
    original_data_modified=FALSE,
    independent_biological_accuracy_certified=FALSE,
    cross_os_binary_image_identity_certified=FALSE)
  jsonlite::write_json(manifest,file.path(stage,"VIZ2_MANIFEST.json"),
                       auto_unbox=TRUE,pretty=TRUE,null="null")
  aqt_viz2_verify(stage)
  if(!file.rename(stage,directory))
    stop("Could not atomically publish staged publication figure",call.=FALSE)
  invisible(directory)
}

#' Verify a published figure's source-row evidence and file hashes
#'
#' Checks every file declared by VIZ2_MANIFEST.json without recomputing
#' scientific estimates or trusting plain filenames. SHA-256 is a corruption
#' and provenance check, not a cryptographic authorship signature.
#'
#' @param directory Existing aqt_viz2_export() directory.
#' @return TRUE invisibly or an error naming the failed file.
#' @export
aqt_viz2_verify <- function(directory) {
  if(!is.character(directory)||length(directory)!=1L||
     is.na(directory)||!dir.exists(directory))
    stop("Expected existing visualization export directory",call.=FALSE)
  file <- file.path(directory,"VIZ2_MANIFEST.json")
  if(!file.exists(file))stop("VIZ2 manifest missing",call.=FALSE)
  m <- jsonlite::fromJSON(file,simplifyVector=FALSE)
  if(!identical(m$schema,"AQT_PUBLICATION_VISUALIZATION_V2_EVIDENCE")||
     is.null(m$output_sha256)||!length(m$output_sha256))
    stop("Malformed VIZ2 manifest schema",call.=FALSE)
  for(name in names(m$output_sha256)) {
    if(!identical(basename(name),name)||
       !nzchar(name)||!file.exists(file.path(directory,name))||
       !identical(.aqt_viz2_file_sha(file.path(directory,name)),
                  as.character(m$output_sha256[[name]])))
      stop("Figure evidence output missing or SHA-256 mismatch: ",name,
           call.=FALSE)
  }
  # Original row-linkage integrity is checked again from the exported CSVs.
  points <- utils::read.csv(file.path(directory,"PLOTTED_SOURCE_POINTS.csv"),
                            colClasses=c(source_row="character",
                                         track_id="character"),
                            stringsAsFactors=FALSE)
  edges <- utils::read.csv(file.path(directory,"ELIGIBLE_SOURCE_SEGMENTS.csv"),
                           colClasses=c(from_source_row="character",
                                        to_source_row="character",
                                        track_id="character"),
                           stringsAsFactors=FALSE)
  decisions <- utils::read.csv(file.path(directory,"ALL_QC_ROW_DECISIONS.csv"),
                               colClasses=c(to_source_row="character",
                                            track_id="character"),
                               stringsAsFactors=FALSE)
  if(nrow(points)!=m$counts$n_source_rows ||
     nrow(edges)!=m$counts$n_eligible_steps ||
     nrow(decisions)!=m$counts$n_source_rows ||
     !setequal(points$source_row,decisions$to_source_row) ||
     anyDuplicated(points$source_row) ||
     (nrow(edges) && (!all(edges$from_source_row %in% points$source_row)||
                      !all(edges$to_source_row %in% points$source_row))))
    stop("Figure source-row lineage is incomplete or inconsistent",
         call.=FALSE)
  invisible(TRUE)
}
