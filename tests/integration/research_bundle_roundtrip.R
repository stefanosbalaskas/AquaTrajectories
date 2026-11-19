# Cross-language validation; Python has already generated the v1 research bundles.
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==1L,dir.exists(args[[1L]]))
suppressPackageStartupMessages(library(aquaTrajectories))
root <- args[[1L]]
kinds <- c("mot_bytetrack","mot_botsort","idtracker_tidy","yolo_csv")
for (kind in kinds) {
  folder <- file.path(root,kind,"bundle")
  b <- aqt_research_bundle_import(folder)
  stopifnot(inherits(b,"aqt_research_bundle"),
            inherits(b$tracks,"aqt_tracks"),
            isTRUE(b$output_sha256_verified),
            !b$clock_independently_verified,
            !b$biological_identity_certified,
            nrow(b$frames)==3L,
            nrow(b$observations)==if(kind=="idtracker_tidy") 3L else 2L,
            all(as.character(b$observations$track_id)=="0007"),
            isTRUE(all.equal(b$frames$time_s,c(0,.055,.17))))
  stopifnot(identical(as.character(b$metadata$tracking_kind),kind))
  if(kind %in% c("mot_bytetrack","mot_botsort")) {
    stopifnot(identical(as.numeric(b$tracks$x),c(15,16)),
              identical(as.numeric(b$tracks$y),c(25,25)),
              isTRUE(all.equal(as.numeric(b$tracks$time_s),c(0,.055))))
  }
  if(kind=="idtracker_tidy") {
    stopifnot(identical(b$observations$observed,c(TRUE,TRUE,FALSE)),
              is.na(b$observations$x[[3L]]),
              is.na(b$observations$y[[3L]]),
              is.na(b$observations$detection_confidence[[1L]]),
              !is.na(b$observations$identity_probability[[1L]]))
  }
  target <- tempfile(paste0("aqt-v1-",kind,"-"),tmpdir=root)
  aqt_research_bundle_export(b,target)
  c <- aqt_research_bundle_import(target)
  stopifnot(identical(b$metadata,c$metadata),
            identical(b$frames,c$frames),
            identical(b$observations,c$observations),
            identical(b$metadata$output_sha256,c$metadata$output_sha256),
            identical(unname(digest::digest(file.path(folder,"manifest.json"),
                                           file=TRUE,algo="sha256")),
                      unname(digest::digest(file.path(target,"manifest.json"),
                                           file=TRUE,algo="sha256"))))
}
b <- aqt_research_bundle_import(file.path(root,"unknown_clock","bundle"))
stopifnot(is.null(b$tracks),
          all(is.na(b$frames$time_s)),
          all(is.na(b$observations$time_s)),
          !b$clock_independently_verified)
cat("PASS: Python -> R 4 trackers + unknown clock; all complete byte-preserving roundtrips\n")
