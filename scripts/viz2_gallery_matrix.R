#!/usr/bin/env Rscript
# Execute ALL 22 public aqt_plot_ functions through the existing gallery
# script, then independently inspect actual headless 3D scene structure twice.
# Source fixtures remain synthetic, no empirical biological truths inferred.
args<-commandArgs(trailingOnly=TRUE)
if(length(args)!=1L||file.exists(args[[1L]])||
   !dir.exists(dirname(args[[1L]])))
  stop("Provide a new destination for Visualization 2.0 gallery evidence")
Sys.setenv(RGL_USE_NULL="TRUE")
options(rgl.useNULL=TRUE)
suppressPackageStartupMessages(library(aquaTrajectories))
if(!requireNamespace("rgl",quietly=TRUE))
  stop("Full native 3D scene testing requires rgl")
gallery<-aqt_viz2_gallery()
if(nrow(gallery)!=22L||sum(gallery$optional_backend)!=6L)
  stop("The complete public plot gallery is not represented")
root<-args[[1L]]
dir.create(root)
parent<-file.path(root,"public_gallery")
run<-suppressWarnings(system2(
  file.path(R.home("bin"),"Rscript"),
  args=c("--vanilla","scripts/qc2_plot_render_matrix.R",
         shQuote(parent)),
  stdout=TRUE,stderr=TRUE))
if(!is.null(attr(run,"status"))&&attr(run,"status")!=0L)
  stop("Original 22-function public plot execution failed:\n",
       paste(tail(run,20),collapse="\n"))
matrix_path<-file.path(parent,"PLOT_RENDER_MATRIX.csv")
if(!file.exists(matrix_path))
  stop("22 public plotting function executions not recorded")
original<-utils::read.csv(matrix_path,stringsAsFactors=FALSE)
if(nrow(original)!=22L||
   !setequal(original$function_name,gallery$function_name)||
   any(original$status!="PASS"))
  stop("Native/optional public gallery execution incomplete")
source_code<-readLines("vignettes/articles/all-plot-functions.Rmd",warn=FALSE)
fence<-strrep(intToUtf8(96L),3L)
extract<-function(tag) {
  idx<-which(startsWith(source_code,paste0(tag,",")) |
             startsWith(source_code,paste0(tag,"}")))
  if(length(idx)!=1L)stop("Unmatched gallery fixture chunk ",tag)
  start<-idx+1L
  end<-which(source_code[seq.int(start,length(source_code))]==fence)[1L]
  if(is.na(end))stop("Unterminated gallery fixture")
  source_code[seq.int(start,start+end-2L)]
}
setup<-extract(paste0(fence,"{r gallery-setup"))
ix<-which(grepl("^library\\(aquaTrajectories\\)",setup))
if(length(ix)!=1L)stop("Gallery setup is not anchored to package namespace")
env<-new.env(parent=globalenv())
eval(parse(text=paste(setup[seq.int(ix,length(setup))],
    collapse="\n")),envir=env)
scenes<-list(
 aqt_plot_path3d="aqt_plot_path3d(toy3)",
 aqt_plot_ensemble3d="aqt_plot_ensemble3d(ensemble3,'S01','SIM','fish1',n_draws=5L)",
 aqt_plot_joint_scene_cloud3d="aqt_plot_joint_scene_cloud3d(cloud)",
 aqt_plot_school3d="aqt_plot_school3d(toy3,'S01','SIM',time_s=5)",
 aqt_plot_tank_scene3d="aqt_plot_tank_scene3d(scene3)",
 aqt_plot_voxel3d="aqt_plot_voxel3d(voxels)")
if(!setequal(names(scenes),
   gallery$function_name[gallery$optional_backend]))
  stop("3D native gallery scene specification mismatch")
measure<-function(code) {
  rgl::open3d()
  on.exit(try(rgl::close3d(),silent=TRUE),add=TRUE)
  eval(parse(text=code),envir=env)
  ids<-rgl::rgl.ids()
  box<-as.numeric(rgl::par3d("bbox"))
  if(!is.data.frame(ids)||!nrow(ids)||!all(c("id","type")%in%names(ids))||
     length(box)!=6L||any(!is.finite(box))||
     any(box[c(2L,4L,6L)]<=box[c(1L,3L,5L)]))
    stop("3D scene lacks nondegenerate finite scene geometry")
  # Object IDs vary with rgl devices. Compare semantic primitive TYPE
  # counts and geometry extents, not transient OpenGL IDs.
  types<-sort(as.character(ids$type))
  list(n_primitive_objects=nrow(ids),types=types,
    bounds=box)
}
scene_reports<-list()
for(name in names(scenes)) {
  one<-measure(scenes[[name]])
  two<-measure(scenes[[name]])
  if(!identical(one$types,two$types)||
     !isTRUE(all.equal(one$bounds,two$bounds,tolerance=1e-9)))
    stop("Headless 3D scene topology/bounds is nondeterministic: ",name)
  scene_reports[[name]]<-data.frame(
    function_name=name,object_count=one$n_primitive_objects,
    type_signature=paste(one$types,collapse=";"),
    min_x=one$bounds[1],max_x=one$bounds[2],
    min_y=one$bounds[3],max_y=one$bounds[4],
    min_z=one$bounds[5],max_z=one$bounds[6],
    scene_repeat_geometry_equal=TRUE,
    scene_reference_type_sha256=unname(digest::digest(
      list(one$types,one$bounds),algo="sha256")),
    stringsAsFactors=FALSE)
}
scenes_df<-do.call(rbind,unname(scene_reports))
rownames(scenes_df)<-NULL
utils::write.csv(scenes_df,file.path(root,"SCENE_GEOMETRY.csv"),
  row.names=FALSE)
original$backend<-gallery$backend[
  match(original$function_name,gallery$function_name)]
original$semantic_3d_geometry_checked<-original$function_name%in%names(scenes)
original$synthetic_gallery_fixture_sha256<-unname(digest::digest(
  "vignettes/articles/all-plot-functions.Rmd",
  file=TRUE,algo="sha256"))
utils::write.csv(original,file.path(root,"COMPLETE_PUBLIC_PLOT_GALLERY.csv"),
                 row.names=FALSE,na="")
hash<-function(x)unname(digest::digest(x,file=TRUE,algo="sha256"))
jsonlite::write_json(list(schema="AQT_VIZ2_ALL_22_NATIVE_GALLERY_V1",
    public_plot_functions=nrow(original),
    verified_native_static_plot_files=sum(!gallery$optional_backend),
    native_scene_functions=nrow(scenes_df),
    all_plot_exports_executed=all(original$status=="PASS"),
    scene_topology_and_bounds_repeated=TRUE,
    image_pixel_regression_companion="viz2_pixel_golden.R",
    published_gallery_source_sha256=unique(original$
      synthetic_gallery_fixture_sha256),
    gallery_sha256=hash(file.path(root,"COMPLETE_PUBLIC_PLOT_GALLERY.csv")),
    scene_geometry_sha256=hash(file.path(root,"SCENE_GEOMETRY.csv")),
    biological_accuracy_certified=FALSE),
  file.path(root,"GALLERY_MANIFEST.json"),
  auto_unbox=TRUE,pretty=TRUE)
cat("VIZ2_COMPLETE_PUBLIC_GALLERY_PASS:",
    nrow(original),"native functions;",nrow(scenes_df),
    "3D scene topologies independently rechecked\n")
