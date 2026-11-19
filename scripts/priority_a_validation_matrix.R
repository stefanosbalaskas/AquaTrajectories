# Priority A -- exact-source qualification manifest and plot-atlas runner.
# Run from the repository root after installing this exact checkout.
# Deliberately distinguish API inventory, test mentions, reference oracles,
# figure rendering and independent empirical/physical validation.
args <- commandArgs(trailingOnly=TRUE)
out <- if(length(args)) args[1L] else "priority-a-evidence"
if(file.exists(out)) stop("Refusing to overwrite an existing evidence folder")
if(!dir.exists(dirname(out))) stop("Output parent must exist")
if(!requireNamespace("aquaTrajectories",quietly=TRUE) ||
   !requireNamespace("yaml",quietly=TRUE) ||
   !requireNamespace("knitr",quietly=TRUE))
  stop("Install exact checkout of aquaTrajectories, yaml and knitr")
dir.create(out)
dir.create(file.path(out,"atlas"))
ns <- readLines("NAMESPACE",warn=FALSE)
exports <- sub("^export\\(([^)]+)\\)$","\\1",
               grep("^export\\(",ns,value=TRUE))
if(length(exports)!=157L || anyDuplicated(exports))
  stop("API count or uniqueness changed: review manifest scope")
cfg <- yaml::read_yaml("_pkgdown.yml")
family <- "Unclassified"
group_rows <- list()
for(section in cfg$reference) {
  if(!is.null(section$title)) family <- section$title
  if(!is.null(section$contents)) {
    group_rows[[length(group_rows)+1L]] <- data.frame(
      function_name=unlist(section$contents,use.names=FALSE),
      family=family,stringsAsFactors=FALSE)
  }
}
groups <- do.call(rbind,group_rows)
if(!setequal(exports,groups$function_name) ||
   anyDuplicated(groups$function_name))
  stop("Unmapped or duplicated exports in reference index")
groups <- groups[match(exports,groups$function_name),,drop=FALSE]
atlas_text <- paste(readLines("vignettes/articles/all-plot-functions.Rmd",
                              warn=FALSE),collapse="\n")
plot_exports <- sort(grep("^aqt_plot_",exports,value=TRUE))
if(length(plot_exports)!=22L) stop("Plot export count changed")
# Actual native plot chunks versus optional 3D input previews. These strings
# are source-label assertions only; they are not visual review certificates.
actual_native <- c(
 "aqt_plot_paths","aqt_plot_calibration_comparison",
 "aqt_plot_changepoints","aqt_plot_ensemble2d",
 "aqt_plot_feeding_states","aqt_plot_grid_pca",
 "aqt_plot_heading_rose","aqt_plot_joint_scene_cloud",
 "aqt_plot_occupancy_timeseries","aqt_plot_reconstruction_qc",
 "aqt_plot_recurrence","aqt_plot_school_dynamics",
 "aqt_plot_speed_response","aqt_plot_tank_changes",
 "aqt_plot_tank_projection","aqt_plot_trajectory_storyboard3d")
three_d_preview <- setdiff(plot_exports,actual_native)
if(length(actual_native)!=16L || length(three_d_preview)!=6L ||
   !setequal(c(actual_native,three_d_preview),plot_exports))
  stop("Plot-mode registry does not match exported functions")
for(name in plot_exports) {
  mode <- if(name %in% three_d_preview) "rgl" else "native"
  needle <- paste0("<h2 id=", '"', "fig-")
  if(!grepl(paste0(name,"()"),atlas_text,fixed=TRUE) ||
     !grepl(paste0('data-mode="',mode,'"'),atlas_text,fixed=TRUE))
    stop("Plot atlas inventory inconsistent: ",name)
}
# Named mathematical oracles from the actual new test file.
reference_tests <- c(
  "aqt_sync_fit","aqt_sync_apply","aqt_trajectory_grid_pca",
  "aqt_trajectory_dtw","aqt_trajectory_recurrence",
  "aqt_group_spatial_summary","aqt_group_pairwise_distances",
  "aqt_group_spatial_edges","aqt_scale_calibrate",
  "aqt_voxel_occupancy","aqt_voxel_entropy",
  "aqt_event_epoch_summary","aqt_tank_event_contrast",
  "aqt_design_audit","aqt_hmm_decode",
  "aqt_rig_new","aqt_rig_validate","aqt_rig_baseline",
  "aqt_rig_project","aqt_triangulate_pairs","aqt_brown_camera",
  "aqt_brown_distort_pixels","aqt_brown_undistort_pixels",
  "aqt_stereo_pixel_mc","aqt_trajectory_ensemble",
  "aqt_ensemble_tracks","aqt_zone_occupancy",
  "aqt_hierarchical_event_prepare","aqt_hierarchical_event_fit",
  "aqt_sparse_fpca_input","aqt_sparse_fpca_design_audit",
  "aqt_sparse_fpca_fit")
if(!all(reference_tests %in% exports)) stop("Oracle registry exports drift")
test_files <- list.files("tests/testthat",pattern="^test-.*\\.R$",
                          full.names=TRUE)
test_sources <- lapply(test_files,readLines,warn=FALSE)
# Mentions are a discovery aid, not evidence a function was executed or
# checked against an oracle (including mentions in comments).
mentions <- vapply(exports,function(name) sum(vapply(test_sources,
  function(source) any(grepl(paste0(name,"("),source,fixed=TRUE)),
  logical(1L))),integer(1L))
matrix <- data.frame(
  function_name=exports,family=groups$family,
  files_with_test_mentions=mentions,
  reference_oracle_added=exports %in% reference_tests,
  rendering_mode=ifelse(exports %in% actual_native,
                        "native_R_atlas",
                 ifelse(exports %in% three_d_preview,
                        "3D_input_preview_not_rgl_capture",
                        "not_a_plot_function")),
  empirical_accuracy_certified=FALSE,
  tested_full_input_domain=FALSE,
  stringsAsFactors=FALSE)
matrix$software_evidence <- ifelse(
  matrix$reference_oracle_added,"independent_mathematical_oracle",
  ifelse(matrix$rendering_mode=="native_R_atlas",
         "native_render_example_only",
  ifelse(matrix$rendering_mode=="3D_input_preview_not_rgl_capture",
         "2D_preview_only__rgl_requires_separate_test",
  ifelse(matrix$files_with_test_mentions>0L,
         "existing_test_mentions__not_independent_oracle",
         "not_independently_qualified"))))
utils::write.csv(matrix,file.path(out,"FUNCTION_VALIDATION_MATRIX.csv"),
                 row.names=FALSE)
checks <- data.frame(check=c(
  "export_registry","pkgdown_reference_groups",
  "named_independent_reference_cases",
  "native_static_plot_gallery","optional_rgl_previews"),
  count=c(length(exports),length(unique(groups$family)),
          length(reference_tests),length(actual_native),
          length(three_d_preview)),
  interpretation=c(
   "Inventory only; not complete scientific validation",
   "All exported names mapped; not scientific validation",
   "Additional testthat oracles; requires exact-head CI success",
   "Actual native plots rendered from synthetic fixtures only",
   "2D input previews do not establish native 3D rendering"),
  stringsAsFactors=FALSE)
utils::write.csv(checks,file.path(out,"QUALIFICATION_COUNTS.csv"),
                 row.names=FALSE)
# Produce all 16 real base R plots and 6 explicitly labeled previews using
# the same source that powers the public function gallery. This is headless
# visualization reproducibility, NOT external biological validation.
old <- getwd()
on.exit(setwd(old),add=TRUE)
setwd(file.path(old,out,"atlas"))
knitr::opts_knit$set(root.dir=old)
knitr::knit(file.path(old,"vignettes/articles/all-plot-functions.Rmd"),
            output="RENDERED_PLOT_ATLAS.md",quiet=TRUE)
images <- list.files(".",pattern="\\.png$",recursive=TRUE,full.names=TRUE)
if(length(images)<22L)
  stop("Fewer than 22 gallery image files: ",length(images))
if(any(file.info(images)$size<=1000))
  stop("At least one figure is empty")
setwd(old)
sink(file.path(out,"SESSION_INFO.txt"))
print(utils::sessionInfo())
sink()
lines <- c(
 "# Priority A — exact-source validation evidence",
 "",
 paste0("- Exported API: ",length(exports)," functions; all listed in FUNCTION_VALIDATION_MATRIX.csv."),
 paste0("- Added distinct independently checked mathematical exports: ",
        length(reference_tests),"."),
 paste0("- Plot atlas: ",length(actual_native),
        " real native R function figures and ",length(three_d_preview),
        " labeled 2D previews of inputs for optional rgl graphics."),
 paste0("- Figure files created by knitr: ",length(images),"."),
 "- Underlying inputs are synthetic analytical fixtures, not ground-truth fish videos.",
 "- Base/stats R, exact geometry and exhaustive enumeration provide numerical comparators.",
 "- Matrix test mentions are NOT independent validation proof.",
 "- RGL input previews are NOT native 3D screenshots; separate optional rgl unit tests are needed.",
 "- No claim of exhaustive numerical accuracy, physical XYZ calibration, welfare, fish identity, or inferential coverage.",
 "- Evidence status is conditional on the matching exact-source CI test runs.",
 "")
writeLines(lines,file.path(out,"README_EVIDENCE.md"))
cat(paste(lines,collapse="\n"))
