# Reproducible scientific report output. Previously estimated scientific results
# are copied unchanged; there is no re-fitting or synthetic filler values.

.aqt_pub_markdown_value <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- "NA"
  x <- gsub("[\r\n|]+"," ",x)
  x
}
.aqt_pub_markdown_table <- function(x) {
  if(!is.data.frame(x)||!nrow(x))return("No rows available.")
  v <- lapply(x,function(z) {
    if(is.numeric(z))
      ifelse(is.na(z),"NA",format(signif(z,6L),trim=TRUE))
    else .aqt_pub_markdown_value(z)
  })
  d <- as.data.frame(v,stringsAsFactors=FALSE)
  head <- paste0("| ",paste(names(d),collapse=" | ")," |")
  bar <- paste0("| ",paste(rep("---",ncol(d)),collapse=" | ")," |")
  rows <- apply(d,1L,function(z)
     paste0("| ",paste(.aqt_pub_markdown_value(z),collapse=" | ")," |"))
  paste(c(head,bar,rows),collapse="\n")
}
.aqt_pub_report_lines <- function(study,catalog,data_origin) {
  a <- study$audit
  qc <- data.frame(metric=c("Original source rows","Eligible reviewed rows",
         "Excluded reviewed rows","Source acquisition frames",
         "Eligible displacement steps","Camera/session scopes"),
       count=c(a$source_rows,a$accepted_positions,a$excluded_rows,
         a$n_source_frames,a$observed_movement_steps,a$n_scopes))
  built <- catalog[catalog$status=="complete",,drop=FALSE]
  skipped <- catalog[catalog$status!="complete",,drop=FALSE]
  captions <- if(nrow(built))unlist(lapply(seq_len(nrow(built)),function(i) {
    z <- built[i,,drop=FALSE]
    file <- strsplit(z$files,";",fixed=TRUE)[[1L]][1L]
    c(paste0("### ",z$figure_id,": ",z$title),"",z$caption,"",
       paste0("Figure: [",file,"](",file,")"),"")
  })) else "No figure passed the source-evidence gate."
  c(
    "# AquaTrajectories: scientific publication report","",
    "This is a generated research report based on existing numerical results, not an independently validated biological study.","",
    paste0("Declared data origin: ",data_origin," (researcher-supplied; not authenticated)."),
    paste0("Source SHA-256: ",a$source_sha256),
    paste0("Analysis schema: ",study$provenance$profile_schema),
    paste0("R package version: ",study$provenance$package_version),"",
    "## Original data and QC accounting","",
    .aqt_pub_markdown_table(qc),"",
    "## Scientific method eligibility","",
    .aqt_pub_markdown_table(
      study$diagnostics[,c("profile","status","reason","n_used"),drop=FALSE]),"",
    "## Publication-ready figure captions","",
    captions,"",
    "## Withheld figures and drawing failures","",
    if(nrow(skipped)).aqt_pub_markdown_table(skipped[,c("figure_id",
          "status","reason"),drop=FALSE]) else "None.","",
    "## Research reporting restrictions","",
    "- Reported image-space pixel movement is not a physical metric without independently validated calibration.",
    "- Camera-local track identifiers are not automatically certified as stable biological individuals.",
    "- Neither event-clock synchronization nor original data origin is independently authenticated by this renderer.",
    "- Frames, individual fish, and observed positions do not replace independent experimental tank replicates.",
    "- Group and event figures are descriptive unless the source analysis explicitly contains a design-eligible model.",
    "- Conditional sensitivity percentiles describe user-defined simulated error scenarios, not confidence intervals.",
    "- Unsupported and missing observations remain missing; no hidden data interpolation or tracker retraining occurs.",
    "- Original source data, excluded raw rows and source timestamps remain in the QC and analysis evidence bundles.","",
    "## Reproducibility inventory","",
    "- analysis/ contains the original frozen Milestone 03 analysis export, including the source and derived data, and its SHA-256 manifest.",
    "- figures/ contains actually rendered PNG and/or vector PDF images, never empty placeholders.",
    "- tables/ contains descriptive tables copied from already calculated scientific outputs.",
    "- FIGURE_CATALOG.csv records which figure was generated, withheld or failed, its caption and the reasons.",
    "- PUBLICATION_MANIFEST.json records file-level SHA-256 hashes and the original raw source digest.",
    "- No original recordings or detector weights are copied into this package.",""
  )
}

#' Export actual scientific figures and a provenance-linked publication report
#'
#' Uses the exact precomputed aqt_scientific_analysis, emits only evidence-
#' supported figures, and records withheld figures and errors. Existing native
#' plotting helpers are reused for school dispersion and independent-tank
#' changes; other plots draw directly from already gap-audited numerical data.
#' PNG plus vector PDF and a self-contained report/evidence archive are
#' produced without introducing new numerical estimates.
#'
#' @param study Source-verified aqt_scientific_analysis.
#' @param directory New output folder; parent directory must already exist.
#' @param formats Unique nonempty selection of png or pdf.
#' @param width,height Physical figure dimensions in inches (3..15).
#' @param dpi PNG resolution in dots/inch, 100..600.
#' @param max_scopes Maximum distinct camera/session figure groups, 1..8.
#' @param data_origin Declared origin: unspecified, synthetic or real.
#' @return Output directory invisibly.
#' @export
aqt_research_publish <- function(study,directory,formats=c("png","pdf"),
                                 width=7.8,height=5.8,dpi=220L,
                                 max_scopes=3L,
                                 data_origin=c("unspecified","synthetic","real")) {
  .aqt_publication_assert(study)
  data_origin <- match.arg(data_origin)
  if (!is.character(directory) || length(directory)!=1L ||
      is.na(directory) || file.exists(directory) ||
      dir.exists(directory) || !dir.exists(dirname(directory)))
    stop("Publication destination must be new with an existing parent",
         call.=FALSE)
  if (!is.character(formats) || !length(formats) || anyNA(formats) ||
      anyDuplicated(formats) || any(!formats %in% c("png","pdf")))
    stop("formats must be unique nonempty png/pdf selections",call.=FALSE)
  for (v in list(width,height))
    if (!is.numeric(v) || length(v)!=1L || !is.finite(v) ||
        v<3 || v>15)
      stop("Figure dimensions must be finite 3..15 inches",call.=FALSE)
  if (!is.numeric(dpi) || length(dpi)!=1L || !is.finite(dpi) ||
      dpi<100 || dpi>600 || dpi!=floor(dpi))
    stop("dpi must be an integer 100..600",call.=FALSE)
  before <- digest::digest(study$review$qc$raw,algo="sha256",serialize=TRUE)
  staging <- tempfile(".aqt-publication-",tmpdir=dirname(directory))
  dir.create(staging)
  on.exit(if(dir.exists(staging))
    unlink(staging,recursive=TRUE,force=TRUE),add=TRUE)
  for(folder in c("figures","tables"))
    dir.create(file.path(staging,folder))
  aqt_research_export(study,file.path(staging,"analysis"))
  catalogue <- aqt_research_figure_plan(study,max_scopes=max_scopes)
  catalogue$status <- ifelse(catalogue$eligible,"pending","skipped")
  catalogue$files <- ""
  for (i in seq_len(nrow(catalogue))) {
    if (!catalogue$eligible[i]) next
    created <- character()
    problem <- ""
    for (fmt in formats) {
      rel <- paste0("figures/",catalogue$figure_id[i],".",fmt)
      full <- file.path(staging,rel)
      result <- .aqt_publication_render(study,
         catalogue[i,,drop=FALSE],full,fmt,width,height,dpi)
      if(!result$ok) { problem <- result$reason;break }
      created <- c(created,rel)
    }
    if(nzchar(problem)) {
      for(path in created) unlink(file.path(staging,path))
      catalogue$status[i] <- "failed"
      catalogue$reason[i] <- problem
    } else {
      catalogue$status[i] <- "complete"
      catalogue$files[i] <- paste(created,collapse=";")
    }
  }
  tables <- list(
    "T01_QC_COUNTS.csv"=data.frame(metric=c("source_rows",
       "review_eligible","review_excluded","source_frames","valid_steps"),
       value=as.numeric(c(study$audit$source_rows,
         study$audit$accepted_positions,study$audit$excluded_rows,
         study$audit$n_source_frames,study$audit$observed_movement_steps))),
    "T02_PROFILE_DECISIONS.csv"=study$diagnostics,
    "T03_CAMERA_COVERAGE.csv"=study$audit$camera_coverage
  )
  if(!is.null(study$movement))
    tables[["T04_INDIVIDUAL_MOVEMENT.csv"]] <-
      study$movement$path_summaries
  if(!is.null(study$schooling))
    tables[["T05_SCHOOL_SPATIAL.csv"]] <-
      study$schooling$spatial_summary
  if(!is.null(study$events))
    tables[["T06_EVENT_EPOCHS.csv"]] <-
      study$events$epoch_summaries
  if(!is.null(study$functional))
    tables[["T07_FUNCTIONAL_SUPPORT.csv"]] <-
      study$functional$coverage
  if(!is.null(study$statistical_models))
    tables[["T08_EXPERIMENTAL_DESIGN.csv"]] <-
      study$statistical_models$design_audit
  if(!is.null(study$uncertainty))
    tables[["T09_POSITION_SENSITIVITY.csv"]] <-
      study$uncertainty$path_sensitivity
  for (name in names(tables))
    utils::write.csv(tables[[name]],
        file.path(staging,"tables",name),row.names=FALSE,na="")
  utils::write.csv(catalogue,file.path(staging,"FIGURE_CATALOG.csv"),
       row.names=FALSE,na="")
  writeLines(.aqt_pub_report_lines(study,catalogue,data_origin),
       file.path(staging,"REPORT.md"),useBytes=TRUE)
  after <- digest::digest(study$review$qc$raw,algo="sha256",serialize=TRUE)
  if(!identical(before,after) ||
     !identical(after,study$audit$source_sha256))
    stop("Source lineage changed during publication",call.=FALSE)
  all <- list.files(staging,recursive=TRUE,full.names=TRUE,
           all.files=FALSE,include.dirs=FALSE)
  rel <- substring(all,nchar(staging)+2L)
  hashes <- as.list(stats::setNames(vapply(all,function(file)
     unname(digest::digest(file,file=TRUE,algo="sha256")),
     character(1L)),rel))
  manifest <- list(schema_version="1.0.0",
    type="aqt_research_publication",
    original_raw_sha256=after,
    analysis_schema=study$provenance$profile_schema,
    package_version=study$provenance$package_version,
    declared_data_origin=data_origin,
    independent_data_origin_verified=FALSE,
    n_figures_complete=sum(catalogue$status=="complete"),
    n_figures_skipped=sum(catalogue$status=="skipped"),
    n_figures_failed=sum(catalogue$status=="failed"),
    n_tables=length(tables),
    formats=formats,figures=catalogue,output_sha256=hashes)
  jsonlite::write_json(manifest,file.path(staging,
      "PUBLICATION_MANIFEST.json"),pretty=TRUE,auto_unbox=TRUE,
      null="null",na="null",digits=17)
  if(!file.rename(staging,directory))
    stop("Could not publish complete scientific report",call.=FALSE)
  invisible(directory)
}
