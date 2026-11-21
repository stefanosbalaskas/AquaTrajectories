#!/usr/bin/env Rscript
# Execute every gallery plot: 16 native PDF renderers and six optional rgl scenes.
# Synthetic-only rendering evidence. Hashes are hardware/device-dependent.
args <- commandArgs(trailingOnly=TRUE)
if(length(args)!=1L || file.exists(args[[1L]]) ||
   !dir.exists(dirname(args[[1L]])))
  stop("Supply new output directory under existing parent")
suppressPackageStartupMessages(library(aquaTrajectories))
source <- readLines("vignettes/articles/all-plot-functions.Rmd",warn=FALSE)
fence <- strrep(intToUtf8(96L),3L)
extract <- function(tag) {
  hit <- which(startsWith(source,tag))
  if(length(hit)!=1L)stop("Missing/duplicate gallery block ",tag)
  start <- hit+1L
  close <- which(source[seq.int(start,length(source))]==fence)[1L]
  if(is.na(close))stop("Unterminated gallery chunk")
  source[seq.int(start,start+close-2L)]
}
setup <- extract(paste0(fence,"{r gallery-setup"))
start <- grep("^library\\(aquaTrajectories\\)",setup)
if(length(start)!=1L)stop("Gallery fixture library marker missing")
fixture <- paste(setup[seq.int(start,length(setup))],collapse="\n")
env <- new.env(parent=globalenv())
eval(parse(text=fixture),envir=env)
plot_line <- source[startsWith(source,paste0(fence,"{r gallery-plot-"))]
chunk_names <- sub("^.*gallery-plot-([^,}]+).*$","\\1",plot_line)
names_in_atlas <- paste0("aqt_plot_",gsub("-","_",chunk_names))
exported <- sort(grep("^aqt_plot_",getNamespaceExports("aquaTrajectories"),
                       value=TRUE))
if(length(exported)!=22L || length(names_in_atlas)!=22L ||
   !setequal(exported,names_in_atlas) || anyDuplicated(names_in_atlas))
  stop("Plotting API and gallery drift")
rgl_expr <- list(
 aqt_plot_path3d="aqt_plot_path3d(toy3)",
 aqt_plot_ensemble3d="aqt_plot_ensemble3d(ensemble3,'S01','SIM','fish1',n_draws=5L)",
 aqt_plot_joint_scene_cloud3d="aqt_plot_joint_scene_cloud3d(cloud)",
 aqt_plot_school3d="aqt_plot_school3d(toy3,'S01','SIM',time_s=5)",
 aqt_plot_tank_scene3d="aqt_plot_tank_scene3d(scene3)",
 aqt_plot_voxel3d="aqt_plot_voxel3d(voxels)")
dir.create(args[[1L]])
figdir <- file.path(args[[1L]],"plots")
dir.create(figdir)
evidence <- list()
for(i in seq_along(names_in_atlas)) {
  fun <- names_in_atlas[i]
  lines <- extract(paste0(fence,"{r gallery-plot-",chunk_names[i]))
  code <- paste(lines,collapse="\n")
  native <- !fun %in% names(rgl_expr)
  if(native && !grepl(paste0("\\b",fun,"\\("),code))
    stop("Native gallery chunk does not execute declared renderer: ",fun)
  if(native) {
    target <- file.path(figdir,paste0(fun,".pdf"))
    grDevices::pdf(target,width=8,height=5,useDingbats=FALSE)
    error <- tryCatch({eval(parse(text=code),envir=env);NULL},
      error=function(e)conditionMessage(e),finally=grDevices::dev.off())
    if(!is.null(error))stop("Native plot failed: ",fun,": ",error)
    if(!file.exists(target) || file.info(target)$size<500 ||
       rawToChar(readBin(target,"raw",n=4))!="%PDF")
      stop("Invalid native output ",fun)
    evidence[[fun]] <- data.frame(function_name=fun,
      output_type="native_pdf",status="PASS",
      output_bytes=file.info(target)$size,
      output_sha256=unname(digest::digest(target,file=TRUE,algo="sha256")))
  } else {
    evidence[[fun]] <- data.frame(function_name=fun,
      output_type="optional_rgl",status="NOT_EXECUTED",
      output_bytes=NA_real_,output_sha256=NA_character_)
  }
}
if(requireNamespace("rgl",quietly=TRUE)) {
  rgl::useNULL()
  for(fun in names(rgl_expr)) {
    rgl::open3d()
    fail <- tryCatch({eval(parse(text=rgl_expr[[fun]]),envir=env);NULL},
       error=function(e)conditionMessage(e))
    ids <- if(is.null(fail))rgl::rgl.ids() else NULL
    rgl::close3d()
    if(!is.null(fail) || is.null(ids) || !nrow(ids))
      stop("Native headless 3D plotting failed: ",fun," ",fail)
    evidence[[fun]]$status <- "PASS"
    evidence[[fun]]$output_bytes <- nrow(ids)
    evidence[[fun]]$output_sha256 <- NA_character_
  }
}
if(identical(Sys.getenv("AQT_REQUIRE_RGL"),"1") &&
    any(vapply(evidence,function(z)z$status!="PASS",logical(1L))))
  stop("Optional 3D render requirement not met")
report <- do.call(rbind,unname(evidence))
rownames(report) <- NULL
utils::write.csv(report,file.path(args[[1L]],"PLOT_RENDER_MATRIX.csv"),
                 row.names=FALSE,na="")
jsonlite::write_json(list(schema="AQT_PLOT_RENDER_BASELINE_V1",
  native_plots_pass=sum(report$output_type=="native_pdf" & report$status=="PASS"),
  optional_rgl_pass=sum(report$output_type=="optional_rgl" & report$status=="PASS"),
  optional_rgl_skipped=sum(report$output_type=="optional_rgl" &
                            report$status!="PASS"),
  cross_platform_pixel_equivalence_certified=FALSE,
  matrix_sha256=unname(digest::digest(
    file.path(args[[1L]],"PLOT_RENDER_MATRIX.csv"),file=TRUE,algo="sha256"))),
  file.path(args[[1L]],"PLOT_RENDER_MANIFEST.json"),
  auto_unbox=TRUE,pretty=TRUE)
cat("PLOT_RENDER_MATRIX: ",sum(report$status=="PASS"),"/22 native executions\n")
