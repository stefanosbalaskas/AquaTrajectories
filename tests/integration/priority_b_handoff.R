# Synthetic-only cross-language contract for external fish tracker positions.
# Run with first command arg pointing to aqt_priority_b_to_r output.
args <- commandArgs(trailingOnly=TRUE)
if(length(args)!=1L || !file.exists(args[[1L]]))
  stop("A canonical externally created fish CSV fixture is required")
library(aquaTrajectories)
t <- aqt_import_csv(args[[1L]],units="px",coordinate_system="image")
stopifnot(inherits(t,"aqt_tracks"),nrow(t)==8L,
          identical(attr(t,"aqt_units"),"px"),
          identical(attr(t,"aqt_coordinate_system"),"image"),
          identical(unique(t$session_id),"TOY_ONLY"),
          identical(unique(t$camera_id),"TOP"),
          all(t$observed),all(t$time_s %in% c(0,.1,.2,.3)))
path <- t[t$track_id=="1",,drop=FALSE]
stopifnot(nrow(path)==4L,
          isTRUE(all.equal(as.numeric(path$time_s),c(0,.1,.2,.3),
                           tolerance=1e-12)))
figure <- tempfile(fileext=".pdf")
grDevices::pdf(figure)
tryCatch({
  aqt_plot_paths(t,max_gap_s=.11)
},finally=grDevices::dev.off())
stopifnot(file.exists(figure),file.info(figure)$size>1000)
cat("PRIORITY_B_PYTHON_TO_R_TRUE_PTS_SCHEMA_AND_NATIVE_PLOT_PASS\n")
