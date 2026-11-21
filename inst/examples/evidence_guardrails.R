# Complete synthetic evidence-safeguards research example.
# No real SmartFish data, detector truth, animal identities or treatment effects.
library(aquaTrajectories)

before <- data.frame(recording="11025",phase="Before",
  time_s=rep(c(.1,1.1,2.1),each=3),
  speed=5,track_id=rep(c("A","B","C"),3),
  stringsAsFactors=FALSE)
during <- data.frame(recording="11025",phase="During",
  time_s=c(rep(.1,3),rep(1.1,3),rep(2.1,100)),
  speed=c(rep(2,6),rep(10,100)),
  track_id=as.character(seq_len(106)),stringsAsFactors=FALSE)
steps <- rbind(before,during)
steps$x <- seq_len(nrow(steps)) %% 11
steps$y <- (seq_len(nrow(steps))*3) %% 17
steps$bbox_area <- (seq_len(nrow(steps)) %% 80)+1
steps$step_eligible <- TRUE

# The intentionally non-uniform sampling yields opposite signs.
spec <- aqt_compare_specifications(steps,eligible_col="step_eligible",
              window_widths=c(1,3),reference_phase="Before")
stopifnot(any(spec$stability$direction_reversal))
p <- subset(spec$contrasts,method=="pooled_steps" & phase=="During")
w <- subset(spec$contrasts,method=="time_window_equal" &
              window_width==1 & phase=="During")
stopifnot(nrow(p)==1L,nrow(w)==1L,
          isTRUE(all.equal(p$difference,5)),
          isTRUE(all.equal(w$difference,-3)))

# Mixed-unit three-axis figure: source depth is NOT calibrated tank Z.
axes <- data.frame(axis=c("x","y","z"),
   variable=c("x","y","bbox_area"),
   unit=c("px","px","source"),calibrated=FALSE)
measurement <- aqt_measurement_contract(axes)
stopifnot(!measurement$physical_3d_eligible)

# Many observations and track IDs do not establish independent fish or tanks.
readiness <- aqt_inference_readiness(steps)
stopifnot(!readiness$experimental_contrast_eligible,
          !readiness$causal_effect_certified)

spatial <- aqt_spatial_support(steps,window_width=1,grid=c(4L,4L),
              min_points_per_window=1L,min_windows=2L)
geometry <- aqt_geometry_bias_audit(steps,n_strata=3L,
              min_per_stratum=1L)

# A separate longer control interval supports internal placebo cuts.
placebo_data <- data.frame(recording="11025",phase="Before",
             time_s=0:11,speed=c(1:6,8:13))
placebo <- aqt_placebo_boundaries(placebo_data,window_width=1,
              min_windows_per_side=3L)
stopifnot(nrow(placebo$cuts)==7L)

report <- aqt_evidence_report(spec,readiness,measurement,
                             spatial,geometry,placebo)
stopifnot(any(report$status$status=="sensitive"),
          any(report$status$status=="blocked"))
target <- tempfile("aqt_evidence_full_example_")
aqt_evidence_export(report,target)
stopifnot(file.exists(file.path(target,"evidence_readme.md")),
          file.exists(file.path(target,"sha256_manifest.csv")))
manifest <- utils::read.csv(file.path(target,"sha256_manifest.csv"),
                           stringsAsFactors=FALSE)
stopifnot(nrow(manifest)>=6L)
for(i in seq_len(nrow(manifest)))
  stopifnot(identical(unname(digest::digest(
       file=file.path(target,manifest$file[i]),algo="sha256")),
       manifest$sha256[i]))

fig <- tempfile("aqt_source_3axis_",fileext=".png")
grDevices::png(fig,width=950,height=750)
tryCatch({
  aqt_plot_source_3axis(steps,measurement,max_points=1000L)
},finally=grDevices::dev.off())
stopifnot(file.exists(fig),file.info(fig)$size>0L)
unlink(fig)
cat("AQT EVIDENCE GUARDRAILS EXAMPLE: PASS\n")
cat("Synthetic sign reversal and 3-axis *display* confirmed.\n")
cat("Report directory:",target,"\n")
