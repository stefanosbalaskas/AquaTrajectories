#!/usr/bin/env Rscript
# AquaTrajectories 0.1.2 — reproducible synthetic TRAJECTORY -> QC -> FIGURES -> REPORT.
# Run from repository root with installed exact-source package.
# Source is an immutable, documented MANUALLY constructed fixture, not animal data.
args <- commandArgs(trailingOnly=TRUE)
if(length(args)!=1L || !is.character(args[1L]) ||
   file.exists(args[1L]) || !dir.exists(dirname(args[1L])))
  stop("Supply a NEW output directory with an existing parent",call.=FALSE)
output <- args[[1L]]
suppressPackageStartupMessages(library(aquaTrajectories))
source_path <- "research/release05/locked_trajectories.csv"
expected_path <- "research/release05/locked_expected.json"
if(!file.exists(source_path)||!file.exists(expected_path))
  stop("Locked original input or expected mathematical truth missing",call.=FALSE)
sha <- function(file) unname(digest::digest(file,file=TRUE,algo="sha256"))
expected <- jsonlite::fromJSON(expected_path,simplifyVector=TRUE)
source_hash <- sha(source_path)
if(!identical(source_hash,
     "b940aedc80b9ca0a2355b5fcc1912cc233ecf6318044bed4d7449ca7ee0be2bc") ||
   !identical(source_hash,expected$source_file_sha256) ||
   !identical(expected$schema,
              "AQT_RELEASE05_LOCKED_SYNTHETIC_TRAJECTORY_V1"))
  stop("LOCKED_SOURCE_SHA256_MISMATCH: refusing to regenerate derived results",
       call.=FALSE)
if(!identical(as.character(utils::packageVersion("aquaTrajectories")),
              "0.1.2"))
  stop("Release05 example must use installed aquaTrajectories version 0.1.2",
       call.=FALSE)
# Explicitly read from original CSV bytes in the report API; no inferred FPS.
qc <- aqt_qc2_report(source_path,gap_limits_s=expected$max_gap_s,
  speed_limits=expected$max_speed_cm_s,step_limits=Inf,
  units=expected$units,coordinate_system=expected$coordinate_system)
if(!identical(qc$source_file_sha256,source_hash) ||
   nrow(qc$policies)!=1L || qc$policies$policy_id[1L]!="QC001")
  stop("Unexpected release05 QC source or policy selection",call.=FALSE)
raw_immutable <- sha(source_path)
led <- qc$lineage
if(nrow(led)!=expected$n_original_source_rows ||
   sum(led$position_observed)!=expected$n_observed_positions ||
   sum(led$step_eligible)!=expected$n_eligible_steps ||
   sum(led$step_status=="excluded_by_policy")!=expected$n_policy_excluded ||
   sum(led$step_status=="not_estimable")!=expected$n_not_estimable)
  stop("Locked source-row inclusion/exclusion counts differ",call.=FALSE)
for(reason in names(expected$exclusion_reasons)) {
  actual <- as.character(led$to_source_row[led$reason_detail==reason])
  if(!setequal(actual,as.character(expected$exclusion_reasons[[reason]])))
    stop("Release05 unexpected QC reason/source-row pair for ",reason,
         call.=FALSE)
}
expected_tracks <- expected$per_track
m <- qc$summary
m <- m[order(m$track_id),,drop=FALSE]
if(nrow(m)!=3L ||
   !identical(as.character(m$track_id),as.character(expected_tracks$track_id)) ||
   !isTRUE(all.equal(as.numeric(m$path_length),
                     as.numeric(expected_tracks$path_length_cm),
                     tolerance=1e-12)) ||
   !identical(as.integer(m$n_eligible_steps),
              as.integer(expected_tracks$eligible_steps)) ||
   !isTRUE(all.equal(as.numeric(m$valid_duration_s),
                     as.numeric(expected_tracks$valid_duration_s),
                     tolerance=1e-12)))
  stop("Known-answer trajectory distances/steps/durations do not reproduce",
       call.=FALSE)
# Additional independent mathematical oracle: direct explicit expected
# source-row edges and Euclidean lengths, NOT derived from QC computed speeds.
reference_edges <- c("A1","A2","A5","B1","B4","B5",
                     "C1","C2","C4","C5")
if(!setequal(as.character(led$to_source_row[led$step_eligible]),reference_edges))
  stop("Independent manually indexed known-answer edge IDs do not match",
       call.=FALSE)
if(!isTRUE(all.equal(sum(m$path_length),10,tolerance=1e-12)) ||
   !isTRUE(all.equal(sum(m$valid_duration_s),10,tolerance=1e-12)))
  stop("Independent known-answer total path length is 10 cm over 10 seconds",
       call.=FALSE)
# Transaction: source and existing outputs never overwritten; exception
# removes only newly created staging data, not user-provided material.
staging <- tempfile(".aqt-release05-",tmpdir=dirname(output))
if(!dir.create(staging))stop("Unable to create staging directory",call.=FALSE)
on.exit(if(dir.exists(staging))unlink(staging,recursive=TRUE,force=TRUE),
        add=TRUE)
dir.create(file.path(staging,"input"))
dir.create(file.path(staging,"figures"))
if(!file.copy(source_path,file.path(staging,"input","locked_trajectories.csv")) ||
   !file.copy(expected_path,file.path(staging,"input","locked_expected.json")) ||
   !identical(sha(file.path(staging,"input","locked_trajectories.csv")),
              source_hash))
  stop("Unable to preserve exact original evidence bytes",call.=FALSE)
aqt_qc2_export(qc,file.path(staging,"qc2"))
kinds <- c("paths","speed","qc_coverage","qc_reasons")
fig_catalog <- list()
for(kind in kinds) {
  spec <- aqt_viz2_spec(qc,figure=kind,policy_id="QC001",
    preset="journal_double",
    caption=paste0("SYNTHETIC source-row/QC-qualified ",kind),
    source_file=source_path)
  if(spec$counts$n_source_rows!=17L ||
     spec$counts$n_eligible_steps!=10L ||
     !identical(spec$provenance$source_file_sha256,source_hash))
    stop("Figure specification lost original scientific provenance",
         call.=FALSE)
  path <- file.path(staging,"figures",kind)
  fmt <- if(kind=="paths") c("pdf","png","svg","tiff") else c("pdf","png")
  aqt_viz2_export(spec,path,formats=fmt)
  stopifnot(isTRUE(aqt_viz2_verify(path,source_file=source_path)))
  fig_catalog[[kind]] <- data.frame(
    figure=kind,policy_id="QC001",source_rows=17L,
    accepted_steps=10L,formats=paste(fmt,collapse=";"),
    original_source_sha256=source_hash,stringsAsFactors=FALSE)
}
catalog <- do.call(rbind,unname(fig_catalog))
rownames(catalog)<-NULL
utils::write.csv(catalog,file.path(staging,"FIGURE_CATALOG.csv"),
                 row.names=FALSE,na="")
results <- data.frame(track_id=as.character(m$track_id),
   n_source_rows=as.integer(m$n_source_rows),
   n_observed_positions=as.integer(m$n_observed_positions),
   n_eligible_steps=as.integer(m$n_eligible_steps),
   n_excluded_steps=as.integer(m$n_excluded_steps),
   path_length_cm=as.numeric(m$path_length),
   valid_duration_s=as.numeric(m$valid_duration_s),
   mean_speed_cm_s=as.numeric(m$mean_speed),
   stringsAsFactors=FALSE)
utils::write.csv(results,file.path(staging,"RESULTS.csv"),
                 row.names=FALSE,na="")
totals <- data.frame(
   source_rows=nrow(led),observed_positions=sum(led$position_observed),
   eligible_steps=sum(led$step_eligible),
   policy_excluded_steps=sum(led$step_status=="excluded_by_policy"),
   not_estimable_rows=sum(led$step_status=="not_estimable"),
   path_length_cm=sum(m$path_length),
   eligible_duration_s=sum(m$valid_duration_s),
   coordinate_units="cm",clock_units="s",dataset_origin="synthetic",
   stringsAsFactors=FALSE)
utils::write.csv(totals,file.path(staging,"QC_TOTALS.csv"),
                 row.names=FALSE,na="")
# Generated report uses ONLY validated derived values and immutable input.
lines <- c(
 "# AquaTrajectories 0.1.2 — locked trajectory-to-report example","",
 "**Data origin: synthetic, manually constructed and frozen.** This is a",
 "reproducible mathematical/software illustration, not real fish tracking",
 "accuracy, fish welfare, underwater metrology or a causal biological result.","",
 "## Source identity","",
 paste0("- Original source SHA-256: `",source_hash,"`"),
 paste0("- Input observations: ",nrow(led),
        "; observed positions: ",sum(led$position_observed)),
 "- Coordinates: cm in a declared tank frame; supplied timestamps: s;",
 "- QC maximum adjacent elapsed time: 1.01 s;",
 "- QC maximum speed: 2 cm/s;",
 "- Frame indices are explicit; skipped frames never become movements.","",
 "## Measured-from-source numerical example","",
 "| Synthetic fish | Original rows | Eligible steps | Eligible path (cm) | Eligible duration (s) |",
 "|:--|--:|--:|--:|--:|",
 unlist(lapply(seq_len(nrow(m)),function(i)
  sprintf("| %s | %d | %d | %.0f | %.0f |",
          m$track_id[i],m$n_source_rows[i],m$n_eligible_steps[i],
          m$path_length[i],m$valid_duration_s[i]))),"",
 paste0("**Total qualified path length: ",sum(m$path_length),
        " cm across ",sum(m$n_eligible_steps)," eligible steps.**"),
 paste0("Source-row accounting: ",
    sum(led$step_status=="excluded_by_policy"),
    " explicitly policy-excluded and ",
    sum(led$step_status=="not_estimable"),
    " not estimable (initial or missing positions)."),"",
 "## Source-linked figures","",
 "- `figures/paths/`: original positions, only QC-accepted movement edges;",
 "- `figures/speed/`: original eligible Euclidean step length / elapsed time;",
 "- `figures/qc_coverage/`: eligible, excluded and unestimable source rows;",
 "- `figures/qc_reasons/`: complete reason distribution.",
 "The first figure includes PDF/SVG vector and PNG/TIFF raster examples;",
 "all four figures include PDF and PNG plus independent plotted-row evidence.","",
 "## Independently reproducible verification","",
 "From the public tagged source root, install the exact R package, then run",
 "`Rscript scripts/release05_example.R OUTPUT_NEW_DIRECTORY` and",
 "`python scripts/release05_verify.py --out OUTPUT_NEW_DIRECTORY`.",
 "The second command uses only the Python standard library: it independently",
 "recomputes eligible source-row pairs and Euclidean distances from the",
 "original 17 CSV rows, verifies all nested/outer SHA-256 manifests, and",
 "cross-checks publication report and figure provenance.","",
 "## Scientific limitations","",
 "- Synthetic source is not biological identity ground truth.",
 "- Numeric cm/s assumes declared seconds, not independently calibrated clocks.",
 "- Figure and report reproducibility do not certify physical calibration.",
 "- Unknown sensor error, fish welfare, causal effects and external generalization",
 "  remain outside this software release's scientific acceptance."
 )
writeLines(lines,file.path(staging,"REPORT.md"),useBytes=TRUE)
writeLines(c("R session at exact release qualification:",
             capture.output(utils::sessionInfo())),
           file.path(staging,"R_SESSION_INFO.txt"),useBytes=TRUE)
if(!identical(sha(source_path),raw_immutable))
  stop("Original input mutated by report creation",call.=FALSE)
rel <- sort(gsub("\\\\","/",list.files(staging,
       recursive=TRUE,all.files=FALSE,full.names=FALSE)))
if(any(!nzchar(rel))||anyDuplicated(rel))
  stop("Artifact path set invalid",call.=FALSE)
file_sha <- as.list(stats::setNames(vapply(rel,function(x)
  sha(file.path(staging,x)),character(1L)),rel))
manifest <- list(
 schema="AQT_RELEASE05_TRAJECTORY_REPORT_V1",
 release_version="0.1.2",dataset_origin="synthetic",
 locked_source_file="input/locked_trajectories.csv",
 original_source_sha256=source_hash,
 original_expected_sha256=sha(expected_path),
 producing_R_script_sha256=sha("scripts/release05_example.R"),
 independent_Python_verifier_sha256=sha("scripts/release05_verify.py"),
 package_version=as.character(utils::packageVersion("aquaTrajectories")),
 R_version=as.character(getRversion()),os=Sys.info()[["sysname"]],
 counts=as.list(totals[1L,,drop=FALSE]),
 source_and_package_have_not_been_modified=TRUE,
 external_biological_accuracy_certified=FALSE,
 output_sha256=file_sha)
jsonlite::write_json(manifest,file.path(staging,"RELEASE05_MANIFEST.json"),
                     pretty=TRUE,auto_unbox=TRUE,null="null",na="null")
if(!file.rename(staging,output))
  stop("Could not finalize atomic research example",call.=FALSE)
cat("RELEASE05_TRAJECTORY_TO_REPORT_PASS: locked original rows",
    nrow(led),"eligible edges",sum(led$step_eligible),
    "source SHA-256",source_hash,"\n")
