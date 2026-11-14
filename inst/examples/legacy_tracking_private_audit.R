# Offline, private research-data quality audit for legacy tracking-style export logs.
#
# This script does NOT send video, data rows, or tracking IDs to GitHub.
# Run after installing an appropriately qualified Wave 17 AquaTrajectories:
#
#   source(system.file("examples/legacy_tracking_private_audit.R",
#                      package="aquaTrajectories",mustWork=TRUE))
#
# It will ask the user to select one original *_tracking_log.txt file;
# all such files in that directory will be audited together. Alternatively
# set options(aqt.tracking.data_dir="C:/path/to/private/logs") before source().

stopifnot(
  as.character(utils::packageVersion("aquaTrajectories")) >= "0.0.38.9000"
)
library(aquaTrajectories)

private_dir <- getOption("aqt.tracking.data_dir",NULL)
if (is.null(private_dir)) {
  if (!interactive()) stop(
    "Set options(aqt.tracking.data_dir=...) when running non-interactively")
  private_dir <- dirname(file.choose())
}
stopifnot(dir.exists(private_dir))
source_files <- list.files(private_dir,pattern="tracking_log\\.txt$",
  full.names=TRUE,ignore.case=TRUE)
if(!length(source_files))stop("No source tracking logs found.")
cat("Source log count:",length(source_files),"\n")
cat("Working directory:",private_dir,"\n")

logs <- lapply(source_files,function(path)
  aqt_import_tracking_log(path))
qc <- aqt_tracking_log_audit(logs)
print(qc[,setdiff(names(qc),"sha256_source"),drop=FALSE])

# Save only aggregate audit tables by default (not individual fish rows).
private_output <- file.path(private_dir,"AquaTrajectories_legacy_tracking_private_QC")
dir.create(private_output,showWarnings=FALSE)
utils::write.csv(qc,file.path(private_output,
                              "source_quality_summary.csv"),
                 row.names=FALSE)

# Reproduce the source's HISTORICAL fixed-scale method only for audit.
# The output numbers are *not* validated physical swimming speeds.
historical <- aqt_tracking_legacy_replay(logs)
print(historical$summary)
utils::write.csv(historical$summary,file.path(private_output,
  "historical_fixedscale_descriptive_only.csv"),row.names=FALSE)

# Draw a single-source exploratory image-plane heading rose.
# Neither pixel position nor original source "Depth(cm)" is converted
# into an independently surveyed 3D fish position.
candidate <- which.max(vapply(logs,nrow,integer(1L)))
tracks <- aqt_tracking_log_tracks(logs[[candidate]],
  duplicate_policy="drop_all",drop_bad_boxes=TRUE,
  drop_boundary=TRUE,drop_depth_cutoff=FALSE)
motion <- aqt_tracking_log_motion(
  tracks,max_gap_s=1,min_displacement_px=1)
heading <- motion[
  is.finite(motion$heading_rad),
  c("condition","heading_rad"),drop=FALSE]
if(nrow(heading)) {
  png_file <- file.path(private_output,"planar_heading_exploratory.png")
  grDevices::png(png_file,width=1800,height=1200,res=150)
  tryCatch(aqt_plot_heading_rose(heading,bins=16,
      scale="fraction",clockwise=FALSE),
    finally=grDevices::dev.off())
  cat("Exploratory rose saved:",png_file,"\n")
} else {
  cat("No reliable nonzero heading steps survived QC.\n")
}
cat("PRIVATE AQTRAJECTORIES LEGACY_TRACKING QC COMPLETE\n")
cat("Output directory:",private_output,"\n")
cat("No experiment-wide timestamps, stable fish identities, physical ",
    "XYZ or replicated feeding treatment effects have been certified.\n",sep="")
